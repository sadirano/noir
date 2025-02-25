# Noir Core Utility Scripts

This repository contains a set of lightweight Windows CMD scripts designed to streamline your workflow for quickly creating and running scripts with minimal keystrokes. The idea is to use **Win + R** to quickly launch these commands, create new scripts, and execute them with parameters.

> **Usage Workflow Example:**  
> - **To create a new script:**  
>   1. Press **Win + R**.  
>   2. Type: `c <script name>` and press **Enter**.  
>   3. Neovim opens with a new file for you to edit.  
> - **To run a script later:**  
>   1. Press **Win + R**.  
>   2. Type: `<script name> <params>` and press **Enter**.

> **Note:** Minimal script names (like `c`, `a`, `n`, etc.) are intentional to reduce keystrokes. While PowerShell is powerful, its requirements (such as always appending `.ps1`) don't align with this fast-launch approach.

---

## Categories & File Descriptions

### 1. Script Creation & Editing
These scripts help you create or edit scripts using Neovim.

- **a.cmd**  
  **Purpose:**  
  - Appends text to a file if arguments are provided.
  - If no additional text is provided, it opens the specified file in Neovim for editing.
  - Automatically creates the directory for the file if it doesn't exist.
  
  **Usage Examples:**  
  - **Edit a Script:**  
    ```batch
    a C:\Scripts\myscript.cmd
    ```
    This opens `myscript.cmd` in Neovim for editing.
  
  - **Append Text to a Script:**  
    ```batch
    a C:\Scripts\myscript.cmd echo Hello World!
    ```
    This appends "echo Hello World!" to the file.

- **c.cmd**  
  **Purpose:**  
  - Opens a file in Neovim.  
  - If no parameters are given, it opens the current directory in Neovim.
  
  **Usage Examples:**  
  - **Edit a Specific File:**  
    ```batch
    c myscript
    ```
    This will open `myscript.cmd` in Neovim.
  - **Open the Current Directory:**  
    ```batch
    c
    ```
    This opens the current directory in Neovim.

- **e.cmd**  
  **Purpose:**  
  - Opens one or more specified files in Neovim for editing.
  
  **Usage Example:**  
    ```batch
    e myscript.cmd
    ```

- **sad.cmd**  
  **Purpose:**  
  - Similar to `e.cmd`, it opens a file in Neovim after changing to the script's directory.
  
  **Usage Example:**  
    ```batch
    sad myscript.cmd
    ```

### 2. Administrative Utilities
These scripts ensure proper permissions are available when needed.

- **adm.cmd**  
  **Purpose:**  
  - Checks for administrative rights.
  - If the current process lacks admin privileges, it relaunches the specified script with elevation via PowerShell.
  
  **Usage Example:**  
    ```batch
    adm someScript.cmd
    ```
    *(Typically used internally by other scripts.)*

- **env.cmd**  
  **Purpose:**  
  - Ensures the script is running with administrative privileges (via `adm.cmd`).
  - Opens the Windows Environment Variables editor.
  
  **Usage Example:**  
    ```batch
    env
    ```

- **hosts.cmd**  
  **Purpose:**  
  - Ensures administrative privileges and opens the system hosts file (`C:\Windows\System32\drivers\etc\hosts`) in Neovim.
  
  **Usage Example:**  
    ```batch
    hosts
    ```

### 3. File & Directory Operations
Scripts in this category assist with file management tasks.

- **ct.cmd**  
  **Purpose:**  
  - Copies a file or directory from a source to a destination.
  - Uses **robocopy** for directories to provide a more robust copy process and uses the standard `copy` command for individual files.
  
  **Usage Examples:**  
  - **Copy a Directory:**  
    ```batch
    ct "C:\SourceFolder" "C:\DestinationFolder"
    ```
  - **Copy a Single File:**  
    ```batch
    ct "C:\source\file.txt" "C:\destination"
    ```

- **n.cmd**  
  **Purpose:**  
  - Creates or appends a note to a file in a sibling directory called `note`.
  - Creates the directory if it doesn't exist.
  
  **Usage Example:**  
    ```batch
    n mynote.txt This is a note.
    ```
    This command will create or append to the file `..\note\mynote.txt`.

### 4. Miscellaneous Utilities
These scripts offer additional utilities to enhance your workflow.

- **fn.cmd**  
  **Purpose:**  
  - Uses the Everything CLI (`es`) to list files, pipes the output to `fzf` for fuzzy searching, and opens the selected file in Neovim.
  
  **Usage Example:**  
    ```batch
    fn
    ```
    *Make sure you have the Everything CLI (`es`) and fzf installed for this to work.*

- **h.cmd**  
  **Purpose:**  
  - Puts the computer to sleep using a DLL call.
  
  **Usage Example:**  
    ```batch
    h
    ```

- **noir.cmd**  
  **Purpose:**  
  - Opens a new CMD prompt in the parent directory of the current location.
  - Sets a custom window title (`Noir`) and clears the screen for a clean appearance.
  
  **Usage Example:**  
    ```batch
    noir
    ```

- **q.cmd**  
  **Purpose:**  
  - Exits the current command prompt session.
  
  **Usage Example:**  
    ```batch
    q
    ```

- **restart.cmd**  
  **Purpose:**  
  - Restarts Windows Explorer by forcefully terminating it and then restarting it.
  
  **Usage Example:**  
    ```batch
    restart
    ```

### 5. Navigation Utilities
This new script provides a single entry point to navigate to a folder or file, offering multiple actions based on the provided arguments.

- **o.cmd**  
  **Purpose:**  
  - Allows you to change to a desired destination folder using a single command.
  - When launched from the Start Menu, it opens the Command Prompt directly at the specified folder.
  - When invoked with the `-s` argument, it opens the folder in Windows Explorer.
  - When invoked with the `-n` argument, it opens the folder in Neovim.
  - If a file name is provided as an argument, it opens that file in Neovim.
  
  **Sample Usage:**  
  - **Open Command Prompt at a Folder:**  
    ```batch
    o %0 %~dpn0 "C:\Desired\Destination"
    ```
    This opens a new Command Prompt in `C:\Desired\Destination`.
  
  - **Open the Folder in Windows Explorer:**  
    ```batch
    o %0 %~dpn0 "C:\Desired\Destination" -s
    ```
  
  - **Open the Folder in Neovim:**  
    ```batch
    o %0 %~dpn0 "C:\Desired\Destination" -n
    ```
  
  - **Open a Specific File in Neovim:**  
    ```batch
    o %0 %~dpn0 "C:\Desired\Destination" "filename.txt"
    ```
    *Here, `%0` is the script name, `%~dpn0` represents the current path, `"C:\Desired\Destination"` is the destination folder, and the fourth parameter is either an option or a file name.*

---

## Additional Notes

- **Workflow Efficiency:**  
  The scripts are designed for rapid development and execution. Minimal names keep the keystrokes low—ideal for launching via **Win + R**.

- **Dependencies:**  
  - **Neovim (nvim):** Must be installed and available in your system's PATH.
  - **Everything CLI (es):** Required for `fn.cmd` to work.
  - **fzf:** Used in conjunction with `es` in `fn.cmd`.
  - **Scoop:** Recommended for installing any missing tools.

