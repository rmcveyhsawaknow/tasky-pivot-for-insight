package database

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/joho/godotenv"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

var Client *mongo.Client

func init() {
	Client = CreateMongoClient()
}

func CreateMongoClient() *mongo.Client {
	godotenv.Overload()
	MongoDbURI := os.Getenv("MONGODB_URI")

	// Create client options with connection pooling and timeouts
	clientOptions := options.Client().
		ApplyURI(MongoDbURI).
		SetMaxPoolSize(10).                         // Maximum number of connections in the pool
		SetMinPoolSize(2).                          // Minimum number of connections in the pool
		SetMaxConnIdleTime(30 * time.Second).       // Maximum time a connection can be idle
		SetServerSelectionTimeout(5 * time.Second). // Server selection timeout
		SetConnectTimeout(10 * time.Second).        // Connection timeout
		SetSocketTimeout(10 * time.Second)          // Socket timeout for operations

	// Create context with timeout for connection
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Connect to MongoDB using the modern Connect function
	client, err := mongo.Connect(ctx, clientOptions)
	if err != nil {
		log.Fatal("Failed to create MongoDB client:", err)
	}

	// Test the connection
	err = client.Ping(ctx, nil)
	if err != nil {
		log.Fatal("Failed to ping MongoDB:", err)
	}

	fmt.Println("Connected to MONGO -> ", MongoDbURI)
	return client
}

func OpenCollection(client *mongo.Client, collectionName string) *mongo.Collection {
	return client.Database("go-mongodb").Collection(collectionName)
}

// GetContext returns a context with timeout for database operations
func GetContext() (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), 10*time.Second)
}
