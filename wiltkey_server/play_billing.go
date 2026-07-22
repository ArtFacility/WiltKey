package main

// Google Play Developer API subscription verification.
//
// The relay cannot take the client's word for a Plus entitlement: anyone can
// build a modified client and POST a made-up purchase token, so without this the
// 72h hold and 50MB uploads are free for the asking. This file resolves a
// purchase token against Google and derives the entitlement expiry from what
// Google actually says.
//
// Configuration (both required to enable):
//   PLAY_CREDENTIALS_FILE — service-account JSON with Play Developer API access
//   PLAY_PACKAGE_NAME     — defaults to xyz.artfacility.wiltkey
//
// When either is unset the verifier is DISABLED and handlePostEntitlement falls
// back to its previous trust-the-client behaviour, so a FOSS/self-hosted relay
// keeps running with zero Google dependencies (the operator sets their own
// policy). Implemented against the stdlib for the same reason as fcm.go: no new
// third-party deps.
//
// NOTE: the JWT/OAuth dance below duplicates the one in fcm.go. Both could move
// onto the shared googleTokenSource here later; fcm.go is deliberately left
// untouched for now since it is deployed and working.

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"
)

const playScope = "https://www.googleapis.com/auth/androidpublisher"

// errPlayNotEntitled means Google answered successfully but the subscription is
// not in a state that grants Plus (expired, paused, on hold, revoked…). This is
// a definitive "no", as opposed to a transport error where we can't tell.
var errPlayNotEntitled = errors.New("play subscription not active")

// PlayVerifier resolves subscription purchase tokens against the Play Developer
// API. The zero value is a disabled verifier whose Verify() is never consulted.
type PlayVerifier struct {
	enabled     bool
	packageName string
	tokens      *googleTokenSource
	httpClient  *http.Client
}

// playVerifier is the process-wide verifier, initialised in main().
var playVerifier = &PlayVerifier{}

// NewPlayVerifier loads the Play service account. Any problem logs a warning and
// returns a disabled verifier — the relay keeps working, it just can't verify.
func NewPlayVerifier() *PlayVerifier {
	path := strings.TrimSpace(os.Getenv("PLAY_CREDENTIALS_FILE"))
	if path == "" {
		log.Printf("[Play] PLAY_CREDENTIALS_FILE not set — purchase-token verification DISABLED (self-hosted mode: entitlement claims are trusted as-is).")
		return &PlayVerifier{}
	}

	pkg := strings.TrimSpace(os.Getenv("PLAY_PACKAGE_NAME"))
	if pkg == "" {
		pkg = "xyz.artfacility.wiltkey"
	}

	raw, err := os.ReadFile(path)
	if err != nil {
		log.Printf("[Play] Could not read PLAY_CREDENTIALS_FILE %q: %v — verification disabled.", path, err)
		return &PlayVerifier{}
	}

	var sa serviceAccount
	if err := json.Unmarshal(raw, &sa); err != nil {
		log.Printf("[Play] Malformed service-account JSON: %v — verification disabled.", err)
		return &PlayVerifier{}
	}
	if sa.ClientEmail == "" || sa.PrivateKey == "" {
		log.Printf("[Play] Service-account JSON missing client_email/private_key — verification disabled.")
		return &PlayVerifier{}
	}
	if sa.TokenURI == "" {
		sa.TokenURI = "https://oauth2.googleapis.com/token"
	}

	key, err := parseRSAPrivateKey(sa.PrivateKey)
	if err != nil {
		log.Printf("[Play] Could not parse service-account private key: %v — verification disabled.", err)
		return &PlayVerifier{}
	}

	log.Printf("[Play] Purchase-token verification enabled for package %s.", pkg)
	return &PlayVerifier{
		enabled:     true,
		packageName: pkg,
		tokens:      &googleTokenSource{sa: sa, privKey: key, scope: playScope, httpClient: &http.Client{Timeout: 15 * time.Second}},
		httpClient:  &http.Client{Timeout: 15 * time.Second},
	}
}

// Enabled reports whether purchase tokens are actually checked against Google.
func (v *PlayVerifier) Enabled() bool { return v != nil && v.enabled }

// subscriptionV2 is the slice of purchases.subscriptionsv2 we care about.
type subscriptionV2 struct {
	SubscriptionState string `json:"subscriptionState"`
	LineItems         []struct {
		ProductID  string `json:"productId"`
		ExpiryTime string `json:"expiryTime"`
	} `json:"lineItems"`
	TestPurchase *struct{} `json:"testPurchase"`
}

// Verify resolves a subscription purchase token and returns the entitlement
// expiry. It returns errPlayNotEntitled when Google says the subscription isn't
// currently granting anything, and a transport error when we simply couldn't ask
// (the caller decides how to treat that — see handlePostEntitlement).
func (v *PlayVerifier) Verify(purchaseToken string) (time.Time, error) {
	if !v.Enabled() {
		return time.Time{}, errors.New("play verification not configured")
	}

	accessToken, err := v.tokens.get()
	if err != nil {
		return time.Time{}, fmt.Errorf("play access token: %w", err)
	}

	endpoint := fmt.Sprintf(
		"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/%s/purchases/subscriptionsv2/tokens/%s",
		v.packageName, purchaseToken,
	)
	req, err := http.NewRequest(http.MethodGet, endpoint, nil)
	if err != nil {
		return time.Time{}, err
	}
	req.Header.Set("Authorization", "Bearer "+accessToken)

	resp, err := v.httpClient.Do(req)
	if err != nil {
		return time.Time{}, fmt.Errorf("play api request: %w", err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)

	switch resp.StatusCode {
	case http.StatusOK:
		// fall through
	case http.StatusNotFound, http.StatusGone:
		// Google has no such token for this package — a forged or foreign token.
		return time.Time{}, errPlayNotEntitled
	default:
		return time.Time{}, fmt.Errorf("play api status %d: %s", resp.StatusCode, string(body))
	}

	var sub subscriptionV2
	if err := json.Unmarshal(body, &sub); err != nil {
		return time.Time{}, fmt.Errorf("decode play response: %w", err)
	}

	// States that still grant the perk. CANCELED means auto-renew is off but the
	// user paid through the current period, so they keep Plus until expiry.
	switch sub.SubscriptionState {
	case "SUBSCRIPTION_STATE_ACTIVE",
		"SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
		"SUBSCRIPTION_STATE_CANCELED":
		// entitled
	default:
		// PENDING / ON_HOLD / PAUSED / EXPIRED / unknown → no perk.
		return time.Time{}, errPlayNotEntitled
	}

	// Take the latest expiry across line items (a sub has one base plan today,
	// but the field is a list and add-ons could appear later).
	var latest time.Time
	for _, li := range sub.LineItems {
		if li.ExpiryTime == "" {
			continue
		}
		t, err := time.Parse(time.RFC3339, li.ExpiryTime)
		if err != nil {
			log.Printf("[Play] Unparseable expiryTime %q: %v", li.ExpiryTime, err)
			continue
		}
		if t.After(latest) {
			latest = t
		}
	}
	if latest.IsZero() {
		return time.Time{}, errPlayNotEntitled
	}
	if !latest.After(time.Now()) {
		// Google reported an entitled state but the period already ended.
		return time.Time{}, errPlayNotEntitled
	}

	if sub.TestPurchase != nil {
		log.Printf("[Play] Verified a LICENSE-TESTER purchase (expires %s).", latest.Format(time.RFC3339))
	}
	return latest, nil
}
