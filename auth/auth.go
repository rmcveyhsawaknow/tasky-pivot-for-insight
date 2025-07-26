package auth

import (
	"net/http"
	"os"
	"time"

	"github.com/dgrijalva/jwt-go"
	"github.com/gin-gonic/gin"
)

type Claims struct {
	Username string `json:"username"`
	jwt.StandardClaims
}

var SECRET_KEY string = os.Getenv("SECRET_KEY")

func ValidateSession(c *gin.Context) bool {
	cookie, err := c.Cookie("token")
	if err != nil {
		// For HTML endpoints, don't send JSON errors - let caller handle redirect
		return false
	}

	token, err := ValidateJWT(cookie)
	if err != nil {
		// For HTML endpoints, don't send JSON errors - let caller handle redirect
		return false
	}

	if !token.Valid {
		// For HTML endpoints, don't send JSON errors - let caller handle redirect
		return false
	}
	return true
}

// ValidateSessionAPI is for API endpoints that need JSON error responses
func ValidateSessionAPI(c *gin.Context) bool {
	cookie, err := c.Cookie("token")
	if err != nil {
		if err == http.ErrNoCookie {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "session expired, please login again"})
			return false
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "error occured while getting cookie"})
		return false
	}

	token, err := ValidateJWT(cookie)
	if err != nil {
		if err == jwt.ErrSignatureInvalid {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized, signature invalid"})
			return false
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "error occured while validating token"})
		return false
	}

	if !token.Valid {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized, invalid token"})
		return false
	}
	return true
}

func GenerateJWT(userid string) (string, error, time.Time) {
	// Declare the expiration time of the token
	// Extended to 2 hours for better demo experience
	expirationTime := time.Now().Add(2 * time.Hour)
	// Create the JWT claims, which includes the username and expiry time
	claims := &Claims{
		Username: userid,
		StandardClaims: jwt.StandardClaims{
			// In JWT, the expiry time is expressed as unix milliseconds
			ExpiresAt: expirationTime.Unix(),
		},
	}

	// Declare the token with the algorithm used for signing, and the claims
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	// Create the JWT string
	tokenString, err := token.SignedString([]byte(SECRET_KEY))

	return tokenString, err, expirationTime
}

func ValidateJWT(token string) (jwt.Token, error) {
	claims := &Claims{}
	tkn, err := jwt.ParseWithClaims(token, claims, func(token *jwt.Token) (interface{}, error) {
		return []byte(SECRET_KEY), nil
	})
	return *tkn, err
}

func RefreshToken(c *gin.Context) (bool, error, time.Time) {

	token, err := c.Cookie("token")
	if err != nil {
		if err == http.ErrNoCookie {
			return true, nil, time.Time{}
		}
		return true, err, time.Time{}
	}

	claims := &Claims{}
	tkn, err := jwt.ParseWithClaims(token, claims, func(token *jwt.Token) (interface{}, error) {
		return []byte(SECRET_KEY), nil
	})
	if err != nil {
		if err == jwt.ErrSignatureInvalid {
			return true, nil, time.Time{}
		}
		return false, err, time.Time{}
	}
	if !tkn.Valid || time.Until(time.Unix(claims.ExpiresAt, 0)) > 30*time.Second {
		return true, nil, time.Unix(claims.ExpiresAt, 0)
	}
	return false, nil, time.Unix(claims.ExpiresAt, 0)
}
