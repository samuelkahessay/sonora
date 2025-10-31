#!/bin/bash
# Sonora Streaming Test Script
# Tests all 6 streaming-enabled analysis modes against the deployed server

set -e

# Configuration
SERVER_URL="${SERVER_URL:-https://sonora.fly.dev}"
TRANSCRIPT="Today I had a really productive meeting about the new project. We discussed the timeline and I'm worried I might have overcommitted. Everyone seemed optimistic, but I feel like I should have pushed back more on the deadlines. I need to email Sarah by Friday about the budget proposal, and I should probably call the client tomorrow at 2pm to discuss the contract details. The team is great but I keep thinking about whether I'm doing enough. Sometimes I wonder if my work even matters in the bigger picture."

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test modes that support streaming
MODES=(
  "distill-summary"
  "distill-actions"
  "distill-reflection"
  "cognitive-clarity"
  "philosophical-echoes"
  "values-recognition"
)

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Sonora AI Analysis Streaming Test Suite                  ║${NC}"
echo -e "${BLUE}║  Server: $SERVER_URL${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Statistics tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to test a streaming mode
test_streaming_mode() {
  local mode=$1
  TOTAL_TESTS=$((TOTAL_TESTS + 1))

  echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}Testing mode: ${mode}${NC}"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Create request payload
  local request_body=$(cat <<EOF
{
  "mode": "${mode}",
  "transcript": "${TRANSCRIPT}",
  "stream": true
}
EOF
)

  # Temporary files for output
  local output_file=$(mktemp)
  local error_file=$(mktemp)
  local counter_file=$(mktemp)
  local final_file=$(mktemp)
  local error_flag_file=$(mktemp)

  # Track timing
  local start_time=$(date +%s%N)

  # Initialize counter files
  echo "0" > "$counter_file"
  echo "false" > "$final_file"
  echo "false" > "$error_flag_file"

  echo -e "${BLUE}[INFO]${NC} Sending streaming request..."
  echo -e "${BLUE}[INFO]${NC} Transcript length: ${#TRANSCRIPT} chars"

  # Make streaming request with curl
  # -N disables buffering, --no-buffer ensures immediate output
  curl -N --no-buffer \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Accept: text/event-stream" \
    -d "${request_body}" \
    "${SERVER_URL}/analyze" \
    2>"$error_file" | while IFS= read -r line; do

    # Process SSE events
    if [[ $line == event:* ]]; then
      event_type="${line#event: }"
      event_type=$(echo "$event_type" | tr -d '\r')
      echo -e "${BLUE}[EVENT]${NC} Received: $event_type"
    elif [[ $line == data:* ]]; then
      data_payload="${line#data: }"
      data_payload=$(echo "$data_payload" | tr -d '\r')

      # Parse the JSON to get partial_text or final data
      if echo "$data_payload" | jq -e '.partial_text' >/dev/null 2>&1; then
        local count=$(cat "$counter_file")
        count=$((count + 1))
        echo "$count" > "$counter_file"
        partial_length=$(echo "$data_payload" | jq -r '.partial_text' | wc -c)
        echo -e "${GREEN}[INTERIM]${NC} Update #${count} - ${partial_length} chars"
      elif echo "$data_payload" | jq -e '.data' >/dev/null 2>&1; then
        echo "true" > "$final_file"
        echo -e "${GREEN}[FINAL]${NC} Complete response received"

        # Extract and display key metrics
        local tokens_in=$(echo "$data_payload" | jq -r '.tokens.input // 0')
        local tokens_out=$(echo "$data_payload" | jq -r '.tokens.output // 0')
        local latency=$(echo "$data_payload" | jq -r '.latency_ms // 0')
        local model=$(echo "$data_payload" | jq -r '.model // "unknown"')

        echo -e "${BLUE}[METRICS]${NC} Model: $model"
        echo -e "${BLUE}[METRICS]${NC} Tokens: ${tokens_in} in / ${tokens_out} out"
        echo -e "${BLUE}[METRICS]${NC} Latency: ${latency}ms"

        # Store final data for validation
        echo "$data_payload" > "$output_file"
      elif echo "$data_payload" | jq -e '.error' >/dev/null 2>&1; then
        echo "true" > "$error_flag_file"
        local error_msg=$(echo "$data_payload" | jq -r '.error')
        echo -e "${RED}[ERROR]${NC} Server error: $error_msg"
      fi
    fi
  done

  local end_time=$(date +%s%N)
  local duration_ms=$(( (end_time - start_time) / 1000000 ))

  # Read results from files
  local interim_count=$(cat "$counter_file")
  local final_received=$(cat "$final_file")
  local error_received=$(cat "$error_flag_file")

  # Check results
  echo ""
  echo -e "${BLUE}[SUMMARY]${NC} Test duration: ${duration_ms}ms"
  echo -e "${BLUE}[SUMMARY]${NC} Interim updates: ${interim_count}"

  local test_passed=true

  # Validation checks
  if [[ $interim_count -eq 0 ]]; then
    echo -e "${RED}[FAIL]${NC} No interim streaming updates received"
    test_passed=false
  else
    echo -e "${GREEN}[PASS]${NC} Received ${interim_count} interim updates"
  fi

  if [[ $final_received == "false" ]]; then
    echo -e "${RED}[FAIL]${NC} No final event received"
    test_passed=false
  else
    echo -e "${GREEN}[PASS]${NC} Final event received"
  fi

  if [[ $error_received == "true" ]]; then
    echo -e "${RED}[FAIL]${NC} Error event received"
    test_passed=false
  fi

  # Validate final JSON structure based on mode
  if [[ -f "$output_file" ]] && [[ -s "$output_file" ]]; then
    case $mode in
      "distill-summary")
        if jq -e '.data.summary' "$output_file" >/dev/null 2>&1; then
          echo -e "${GREEN}[PASS]${NC} Valid summary structure"
        else
          echo -e "${RED}[FAIL]${NC} Invalid summary structure"
          test_passed=false
        fi
        ;;
      "distill-actions")
        if jq -e '.data.action_items | type == "array"' "$output_file" >/dev/null 2>&1; then
          echo -e "${GREEN}[PASS]${NC} Valid actions structure"
        else
          echo -e "${RED}[FAIL]${NC} Invalid actions structure"
          test_passed=false
        fi
        ;;
      "distill-reflection")
        if jq -e '.data.reflection_questions | type == "array"' "$output_file" >/dev/null 2>&1; then
          echo -e "${GREEN}[PASS]${NC} Valid reflection structure"
        else
          echo -e "${RED}[FAIL]${NC} Invalid reflection structure"
          test_passed=false
        fi
        ;;
      "cognitive-clarity")
        if jq -e '.data.cognitivePatterns | type == "array"' "$output_file" >/dev/null 2>&1; then
          echo -e "${GREEN}[PASS]${NC} Valid cognitive clarity structure"
        else
          echo -e "${RED}[FAIL]${NC} Invalid cognitive clarity structure"
          test_passed=false
        fi
        ;;
      "philosophical-echoes")
        if jq -e '.data.philosophicalEchoes | type == "array"' "$output_file" >/dev/null 2>&1; then
          echo -e "${GREEN}[PASS]${NC} Valid philosophical echoes structure"
        else
          echo -e "${RED}[FAIL]${NC} Invalid philosophical echoes structure"
          test_passed=false
        fi
        ;;
      "values-recognition")
        if jq -e '.data.coreValues | type == "array"' "$output_file" >/dev/null 2>&1; then
          echo -e "${GREEN}[PASS]${NC} Valid values recognition structure"
        else
          echo -e "${RED}[FAIL]${NC} Invalid values recognition structure"
          test_passed=false
        fi
        ;;
    esac
  fi

  # Check for curl errors
  if [[ -s "$error_file" ]]; then
    echo -e "${YELLOW}[WARN]${NC} Curl stderr output:"
    cat "$error_file"
  fi

  # Update statistics
  if [[ $test_passed == true ]]; then
    PASSED_TESTS=$((PASSED_TESTS + 1))
    echo -e "\n${GREEN}✓ Test PASSED${NC}"
  else
    FAILED_TESTS=$((FAILED_TESTS + 1))
    echo -e "\n${RED}✗ Test FAILED${NC}"
  fi

  # Cleanup
  rm -f "$output_file" "$error_file" "$counter_file" "$final_file" "$error_flag_file"
}

# Run tests for all modes
for mode in "${MODES[@]}"; do
  test_streaming_mode "$mode"
  # Small delay between tests to avoid rate limiting
  sleep 1
done

# Final summary
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Test Results Summary                                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo -e "Total Tests:  ${TOTAL_TESTS}"
echo -e "${GREEN}Passed:       ${PASSED_TESTS}${NC}"
if [[ $FAILED_TESTS -gt 0 ]]; then
  echo -e "${RED}Failed:       ${FAILED_TESTS}${NC}"
else
  echo -e "Failed:       ${FAILED_TESTS}"
fi
echo ""

if [[ $FAILED_TESTS -eq 0 ]]; then
  echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║  ALL TESTS PASSED! ✓                                       ║${NC}"
  echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
  exit 0
else
  echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${RED}║  SOME TESTS FAILED ✗                                       ║${NC}"
  echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
  exit 1
fi
