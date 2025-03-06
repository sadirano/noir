# Noir Core Utility Scripts

This repository contains a set of lightweight Windows CMD scripts designed to streamline your workflow for quickly creating and running scripts with minimal keystrokes. The idea is to use **Win + R** to quickly launch these commands, create new scripts, and execute them with parameters.

> **Note:** Minimal script names (like `c`, `a`, `n`, etc.) are intentional to reduce keystrokes. While PowerShell is powerful, its requirements (such as always appending `.ps1`) don't align with this fast-launch approach.

---

- **hosts.cmd** Ensures administrative privileges and opens the system hosts file (`C:\Windows\System32\drivers\etc\hosts`) in Neovim.
  
- **fn.cmd**  Uses the Everything CLI (`es`) to list files, pipes the output to `fzf` for fuzzy searching, and opens the selected file in Neovim.
  
  **Usage Example:**  
    ```batch
    fn
    ```
    *Make sure you have the Everything CLI (`es`) and fzf installed for this to work.*

- **omni.cmd** (outdated: see omni /? for updated help)
  **Purpose:**  
  - Allows you to change to a desired destination folder using a single command.
  - When launched from the Start Menu, it opens the Command Prompt directly at the specified folder.
  - When invoked with the `-s` argument, it opens the folder in Windows Explorer.
  - When invoked with the `-n` argument, it opens the folder in Neovim.
  - If a file name is provided as an argument, it opens that file in Neovim.
  
  **Sample Usage:**  
  - **Open Command Prompt at a Folder:**  
    ```batch
    omni %0 %~dpn0 "C:\Desired\Destination"
    ```
    This opens a new Command Prompt in `C:\Desired\Destination`.
  
  - **Open the Folder in Windows Explorer:**  
    ```batch
    omni %0 %~dpn0 "C:\Desired\Destination" -s
    ```
  
  - **Open the Folder in Neovim:**  
    ```batch
    omni %0 %~dpn0 "C:\Desired\Destination" -n
    ```
  
  - **Open a Specific File in Neovim:**  
    ```batch
    omni %0 %~dpn0 "C:\Desired\Destination" "filename.txt"
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

