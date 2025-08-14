def wasm_to_blob_string(file_path: str) -> str:
    """
    Reads a binary file and converts its content into an escaped string blob.

    Args:
        file_path: The path to the local .wasm file.

    Returns:
        The Blob string representation or an error message.
    """
    try:
        with open(file_path, 'rb') as file:
            binary_content = file.read()
            escaped_string = "".join([f'\\{byte:02x}' for byte in binary_content])
            return escaped_string
    except FileNotFoundError:
        return f"Error: File not found at '{file_path}'."
    except Exception as e:
        return f"An error occurred: {e}"

# --- Main execution ---

# 1. Define the input and output file names
input_wasm_file = 'user.wasm'
output_motoko_file = 'output.mo'

# 2. Call the function to perform the conversion
blob_output = wasm_to_blob_string(input_wasm_file)

# 3. Check if the conversion was successful
if not blob_output.startswith("Error"):
    # Create the full line of Motoko code
    motoko_code = f'let wasm: Blob = "{blob_output}";'
    
    # Write the code to the specified .mo file
    with open(output_motoko_file, 'w', encoding='utf-8') as f:
        f.write(motoko_code)
    
    print(f"Success! ✅ Wasm blob has been saved to '{output_motoko_file}'.")
else:
    # Print the error message if something went wrong
    print(blob_output)