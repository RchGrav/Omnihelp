#!/bin/bash

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# Function to suggest corrections using the ChatGPT API
engage_ai() {
    local last_command="$1"
    # API call setup
    local API_URL="https://api.openai.com/v1/chat/completions"
    local API_KEY="${OPENAI_API_KEY}"

    # Initialize the messages array with the assistant's role
    if [ -z "$MESSAGES" ]; then
        MESSAGES=$(jq -n --arg content "You are an AI assistant specialized in helping users operate Linux from the Bash shell. Your role is to assist users by receiving their questions or communications and providing appropriate commands or actions to achieve their goals. You can: Interpret User Queries: Understand the user's questions or tasks related to operating Linux. Provide Commands: Offer the correct Bash commands needed to accomplish the task. Collect and Verify Data: Independently check system configurations, such as verifying if paths are set up correctly or executing commands to check their results. Interact with Files: View, append, or edit the contents of files as required to complete the task. Guide Users: Explain the steps and commands to help users learn and understand the process. Archiving Interactions: Ask the user if they are satisfied with what was accomplished and if it's okay to archive the interaction. If approved, rename the interaction log to a dated file and save it in a completed_tasks folder." '
        [{
            "role": "assistant",
            "content": $content
        }]')
    fi

    MESSAGES=$(echo "$MESSAGES" | jq --arg content "$last_command" '. + [{"role": "user", "content": $content}]')

    # Construct the DATA JSON object with the updated MESSAGES array
    DATA=$(jq -n --argjson messages "$MESSAGES" '
    {
        "model": "gpt-4o",
        "tool_choice": "required",
        "messages": $messages,
        "tools": [{
            "type": "function",
            "function": {
                "name": "omni_command",
                "description": "Provides a JSON object with response from the AI to assist with the linux shell.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "responseType": {
                            "type": "string",
                            "description": "Indicates the type of response, such as '\''communication'\'', '\''taskOffer'\'', or '\''commandExecution'\''."
                        },
                        "aiResponse": {
                            "type": "string",
                            "description": "Contains the AI'\''s direct response to the user, which can include explanations or instructions."
                        },
                        "command": {
                            "type": "string",
                            "description": "A command that the AI suggests or intends to execute. This helps in automating the command execution process."
                        },
                        "notes": {
                            "type": "string",
                            "description": "A summary or important notes about the interaction that will be appended to interaction_log.txt."
                        },
                        "status": {
                            "type": "string",
                            "description": "Indicates the current state of the interaction. It can be '\''conversing'\'', '\''complete'\'', or '\''need_more_info'\''."
                        }
                    },
                    "required": ["responseType", "aiResponse", "notes", "status"]
                }
            }
        }]
    }')

    # Make the request and store the response
    local response=$(curl -s -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $API_KEY" \
        -d "$DATA")


    # Check if the response is empty or invalid
    if [ -z "$response" ] || ! echo "$response" | jq -e . >/dev/null 2>&1; then
        echo "Error: Invalid or empty API response."
        return
    fi

    # Extract the 'arguments' as JSON string
    local arguments_json=$(echo $response | jq -r '.choices[0].message.tool_calls[0].function.arguments')

    # Decode the JSON string to get the individual fields
    local responseType=$(echo $arguments_json | jq -r '.responseType')
    local aiResponse=$(echo $arguments_json | jq -r '.aiResponse')
    # Check if the 'command' field exists and is not null
    if echo "$arguments_json" | jq -e '.command | select(. != null)' >/dev/null 2>&1; then
        local command=$(echo $arguments_json | jq -r '.command')
    else
        local command=""
    fi
    local notes=$(echo $arguments_json | jq -r '.notes')
    local status=$(echo $arguments_json | jq -r '.status')

    # Print the AI's response with ANSI escape sequences for formatting
    echo -e "${YELLOW}AI Response:${NC} $(echo -e "$aiResponse")"

# Prompt user for confirmation before executing command
if [ -n "$command" ]; then
    # Escape the command for display purposes
    local display_command=$(printf "%q" "$command")

    # Display the command for user confirmation
    read -p "$(echo -e "\nThe AI suggests the following command(s) to be executed...\n\n$display_command\n\nDo you want to proceed? (y/n) ")" user_response

    if [[ "$user_response" == "y" ]]; then
        echo -e "\n${GREEN}Executing Command:${NC} $command"
        # Use printf to handle special characters and multiline strings
        local safe_command=$(printf "%s" "$command")
        eval "$safe_command"
    else
        echo -e "\n${RED}Command execution aborted by the user.${NC}"
    fi
fi

    # Append the AI's response and notes to interaction_log.txt
    echo "Assistant: $aiResponse" >> "$SCRIPT_DIR/interaction_log.txt"
    echo "Notes: $notes" >> "$SCRIPT_DIR/interaction_log.txt"

    # Check the interaction status
    if [ "$status" == "complete" ]; then
        unset MESSAGES
        mkdir -p "$SCRIPT_DIR/completed_tasks"
        mv "$SCRIPT_DIR/interaction_log.txt" "$SCRIPT_DIR/completed_tasks/interaction_log_$(date +'%Y%m%d_%H%M%S').txt"
        echo -e "\n${GREEN}Interaction log archived successfully.${NC}"
    elif [ "$status" == "conversing" ]; then
        read -p "$(echo -e "${YELLOW}User Response:${NC} ")" user_input
        MESSAGES=$(echo "$MESSAGES" | jq --arg content "$aiResponse" '. + [{"role": "assistant", "content": $content}]')
        MESSAGES=$(echo "$MESSAGES" | jq --arg content "$user_input" '. + [{"role": "user", "content": $content}]')
        engage_ai "$user_input"
    elif [ "$status" == "need_more_info" ]; then
        read -p "$(echo -e "\nPlease provide the additional information requested: ")" user_input
        MESSAGES=$(echo "$MESSAGES" | jq --arg content "$aiResponse" '. + [{"role": "assistant", "content": $content}]')
        MESSAGES=$(echo "$MESSAGES" | jq --arg content "$user_input" '. + [{"role": "user", "content": $content}]')
        engage_ai "$user_input"
    fi
}

# Function to check the last command and respond if it starts with '#'
check_last_command() {
    # Get the last command entered, including the command number
    local last_command_with_number=$(history 1)

    # Extract the command number
    local command_number=$(echo "$last_command_with_number" | awk '{print $1}')

    # Get the last command entered, excluding the command number
    local last_command=$(echo "$last_command_with_number" | sed 's/^[ ]*[0-9]*[ ]*//')

    # Check if the command number matches the contents of .sequence file
    if [ -f "$SCRIPT_DIR/.sequence" ] && [ "$(cat "$SCRIPT_DIR/.sequence")" == "$command_number" ]; then
        return
    fi

    # Update the .sequence file with the current command number
    echo "$command_number" > "$SCRIPT_DIR/.sequence"

    # Check if the last command starts with '#'
    if [[ "$last_command" == \#* ]]; then
        # Extract the text after '#'
        local typed_text=${last_command:1}
        engage_ai "$typed_text"
    fi
}
# Set this function to run before each prompt
unset PROMPT_COMMAND
PROMPT_COMMAND="check_last_command; $PROMPT_COMMAND"
