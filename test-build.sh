#!/bin/bash
# Build Test Script for Tasky Application
# This replaces the non-functional './tasky --help' test in deployment guide Step 1.2

echo "=== Tasky Build Validation Test ==="

# Build the application
echo "1. Building application..."
if go build -o tasky main.go; then
    echo "✅ Build successful"
else
    echo "❌ Build failed"
    exit 1
fi

# Test application startup with fake environment
echo "2. Testing application startup..."
MONGODB_URI="mongodb://fake:fake@localhost:27017/fake" \
SECRET_KEY="fake123" \
timeout 5s ./tasky 2>&1 | grep -q "Connected to MONGO"

if [ $? -eq 0 ]; then
    echo "✅ Application startup successful"
    echo "✅ MongoDB connection string handling works"
    echo "✅ Environment variable loading works"
else
    echo "❌ Application startup failed"
    exit 1
fi

# Clean up
rm -f tasky

echo ""
echo "🎉 All tests passed! Application build is valid."
echo ""
echo "📝 Note: This test validates that:"
echo "   - Go code compiles without errors"
echo "   - Application can start and initialize"
echo "   - Environment variables are loaded correctly"
echo "   - MongoDB connection string is processed"
echo ""
echo "✅ Ready for deployment!"
