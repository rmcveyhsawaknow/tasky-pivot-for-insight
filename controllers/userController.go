package controller

import (
	"log"
	"net/http"
	"os"

	"github.com/gin-gonic/gin"
	"github.com/jeffthorne/tasky/auth"
	"github.com/jeffthorne/tasky/database"
	"github.com/jeffthorne/tasky/models"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"golang.org/x/crypto/bcrypt"
)

var SECRET_KEY string = os.Getenv("SECRET_KEY")
var userCollection *mongo.Collection = database.OpenCollection(database.Client, "user")

func SignUp(c *gin.Context) {
	var user models.User
	if err := c.BindJSON(&user); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Use the database helper for consistent context management
	ctx, cancel := database.GetContext()
	defer cancel()

	// Check if user with this email already exists
	emailCount, err := userCollection.CountDocuments(ctx, bson.M{"email": user.Email})
	if err != nil {
		log.Printf("Error checking email existence: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "error occurred while checking for the email"})
		return
	}

	if emailCount > 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "User with this email already exists!"})
		return
	}

	// Validate required fields
	if user.Email == nil || user.Password == nil || user.Name == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Email, password, and username are required"})
		return
	}

	// Hash the password
	password := HashPassword(*user.Password)
	user.Password = &password
	user.ID = primitive.NewObjectID()

	// Insert the user
	resultInsertionNumber, insertErr := userCollection.InsertOne(ctx, user)
	if insertErr != nil {
		log.Printf("Error inserting user: %v", insertErr)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "user was not created"})
		return
	}

	// Generate JWT token and set cookies
	userId := user.ID.Hex()
	username := *user.Name

	token, err, expirationTime := auth.GenerateJWT(userId)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "error occurred while generating token"})
		return
	}

	http.SetCookie(c.Writer, &http.Cookie{
		Name:    "token",
		Value:   token,
		Expires: expirationTime,
	})

	http.SetCookie(c.Writer, &http.Cookie{
		Name:    "userID",
		Value:   userId,
		Expires: expirationTime,
	})

	http.SetCookie(c.Writer, &http.Cookie{
		Name:    "username",
		Value:   username,
		Expires: expirationTime,
	})

	c.JSON(http.StatusOK, resultInsertionNumber)
}
func Login(c *gin.Context) {
	var user models.User
	var foundUser models.User

	if err := c.BindJSON(&user); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "bind error"})
		return
	}

	// Use consistent context management
	ctx, cancel := database.GetContext()
	defer cancel()

	// Find user by email
	err := userCollection.FindOne(ctx, bson.M{"email": user.Email}).Decode(&foundUser)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "email or password is incorrect"})
		return
	}

	// Verify password
	passwordIsValid, msg := VerifyPassword(*user.Password, *foundUser.Password)
	if !passwordIsValid {
		c.JSON(http.StatusInternalServerError, gin.H{"error": msg})
		return
	}

	if foundUser.Email == nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "User not found!"})
		return
	}

	userId := foundUser.ID.Hex()
	username := *foundUser.Name

	shouldRefresh, err, expirationTime := auth.RefreshToken(c)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "refresh token error"})
		return
	}

	if shouldRefresh {
		token, err, expirationTime := auth.GenerateJWT(userId)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "error occured while generating token"})
			return
		}

		http.SetCookie(c.Writer, &http.Cookie{
			Name:    "token",
			Value:   token,
			Expires: expirationTime,
		})

		http.SetCookie(c.Writer, &http.Cookie{
			Name:    "userID",
			Value:   userId,
			Expires: expirationTime,
		})
		http.SetCookie(c.Writer, &http.Cookie{
			Name:    "username",
			Value:   username,
			Expires: expirationTime,
		})

	} else {
		http.SetCookie(c.Writer, &http.Cookie{
			Name:    "userID",
			Value:   userId,
			Expires: expirationTime,
		})
		http.SetCookie(c.Writer, &http.Cookie{
			Name:    "username",
			Value:   username,
			Expires: expirationTime,
		})
	}
	c.JSON(http.StatusOK, gin.H{"msg": "login successful"})
}

func Todo(c *gin.Context) {
	session := auth.ValidateSession(c)
	if session {
		c.HTML(http.StatusOK, "todo.html", nil)
	} else {
		// Redirect unauthorized users back to login page
		c.Redirect(http.StatusFound, "/")
	}
}

func HashPassword(password string) string {
	bytes, err := bcrypt.GenerateFromPassword([]byte(password), 14)
	if err != nil {
		log.Panic(err)
	}
	return string(bytes)
}

func VerifyPassword(userPassword string, providedPassword string) (bool, string) {
	err := bcrypt.CompareHashAndPassword([]byte(providedPassword), []byte(userPassword))
	check := true
	msg := ""

	if err != nil {
		msg = "email or password is incorrect"
		check = false
	}

	return check, msg
}
