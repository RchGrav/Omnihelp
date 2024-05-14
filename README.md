# GPT-4o Bash Assistant

This script leverages the power of GPT-4o to provide an interactive AI assistant for Linux users directly from the Bash shell. With this script, you can ask questions, get suggested commands, and automate tasks using natural language.

## Prerequisites

- Bash shell
- curl
- jq

## Setup

1. Sign up for an API key at [OpenAI](https://www.openai.com/) if you don't already have one.

2. Set your OpenAI API key as an environment variable:

   ```bash
   export OPENAI_API_KEY="your_api_key_here"
   ```

   It's recommended to add this line to your `.bashrc` or `.bash_profile` file so that the environment variable is set every time you open a new terminal session.

3. Download the script and save it in your home directory with a name like `gpt4o_assistant.sh`:

   ```bash
   wget -O ~/gpt4o_assistant.sh "https://raw.githubusercontent.com/RchGrav/gpt4o_assistant/main/gpt4o_assistant.sh"
   ```

4. Make the script executable:

   ```bash
   chmod +x ~/gpt4o_assistant.sh
   ```

5. Add the following line at the end of your `.bashrc` file to source the script:

   ```bash
   source ~/gpt4o_assistant.sh
   ```

   This ensures that the script is loaded every time you open a new terminal session.

6. Restart your terminal or run `source ~/.bashrc` to apply the changes.

## Usage

To interact with the AI assistant, simply type `#` followed by your question or command in the terminal:

```bash
# how do I find all files larger than 10MB in my home directory?
```

The script will send your query to the GPT-4o API and display the AI's response. If the AI suggests a command to be executed, you will be prompted for confirmation before proceeding.

The conversation history and notes will be stored in an `interaction_log.txt` file in the same directory as the script. When an interaction is marked as complete by the AI, the log file will be renamed with a timestamp and moved to a `completed_tasks` folder.

To continue an ongoing interaction, simply type `#` followed by your response to the AI's previous message.

## Customization

Feel free to customize the script to fit your specific needs. You can modify the AI's role, the structure of the API request, and the handling of different response types.

## Troubleshooting

If you encounter any issues, make sure you have the required prerequisites installed and that your API key is set correctly. Check the API response for any error messages and consult the OpenAI documentation for further assistance.

## License

This script is released under the [MIT License](https://opensource.org/licenses/MIT).

## Acknowledgements

Special thanks to the OpenAI team for creating the GPT-4o model and providing the API that makes this script possible.
