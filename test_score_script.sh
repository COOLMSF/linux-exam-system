#!/bin/bash

# Test script for score.sh variable replacement

echo "=== Testing score.sh script ==="
echo ""

# Test 1: Basic execution with username
echo "Test 1: Basic execution with username"
echo "Command: ./score.sh testuser"
echo "Expected: Should execute and output SCORE:X:testuser"
./score.sh testuser 2>&1 | grep -i "score:"
echo ""

# Test 2: Check if username is correctly passed
echo "Test 2: Check if username is correctly passed"
echo "Command: ./score.sh testuser"
echo "Expected: Should contain 'Scoring for user: testuser'"
./score.sh testuser 2>&1 | grep -i "Scoring for user"
echo ""

# Test 3: Test without username
echo "Test 3: Test without username"
echo "Command: ./score.sh"
echo "Expected: Should show error message"
./score.sh 2>&1 | grep -i "error"
echo ""

# Test 4: Check if variables are correctly defined
echo "Test 4: Check if script contains variable definitions"
echo "Expected: Should contain variable assignments like USERNAME=, a1=, etc."
grep -E "USERNAME=|a[1-9]=|total=" ./score.sh
echo ""

# Test 5: Check log file creation logic
echo "Test 5: Check log file creation logic"
echo "Expected: Should contain log file creation with timestamp"
grep -i "LOG_FILE=" ./score.sh
echo ""

echo "=== Test completed ==="
