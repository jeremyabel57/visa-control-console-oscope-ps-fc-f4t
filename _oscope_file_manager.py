import sys
import os
import subprocess
import configparser

# ==========================================
# AUTOMATIC DEPENDENCY INSTALLATION FUNCTION
# ==========================================
def install_dependencies():
    """Checks for required external modules and installs them if missing."""
    required_packages = {
        "pyvisa": "pyvisa"
    }
    
    missing_packages = []
    for module_name, pip_name in required_packages.items():
        try:
            __import__(module_name)
        except ImportError:
            missing_packages.append(pip_name)
            
    if missing_packages:
        print(f"Missing required packages: {missing_packages}. Attempting automatic installation...")
        try:
            subprocess.check_call([sys.executable, "-m", "pip", "install", *missing_packages])
            print("Successfully installed missing dependencies!")
        except Exception as e:
            print(f"Error: Automatic installation failed. Please run 'pip install pyvisa' manually. Details: {e}")
            sys.exit(1)

# Run dependency check before importing the GUI packages
install_dependencies()

# Core imports
import tkinter as tk
from tkinter import ttk, messagebox, filedialog
import pyvisa

# ==========================================
# CONFIGURATION INI LOGIC
# ==========================================
INI_FILE = "config.ini"

def load_settings():
    """Loads IP and Last Folder configuration data from the local INI file."""
    config = configparser.ConfigParser()
    settings = {"ip": "192.168.1.100", "folder": ""}
    
    if os.path.exists(INI_FILE):
        try:
            config.read(INI_FILE)
            if "Connection" in config:
                settings["ip"] = config["Connection"].get("IPAddress", settings["ip"])
                settings["folder"] = config["Connection"].get("LastFolder", settings["folder"])
        except Exception as e:
            print(f"Warning: Could not parse config.ini file: {e}")
    return settings

def save_settings(ip_address, last_folder):
    """Saves active IP and current folder paths to the config.ini file."""
    config = configparser.ConfigParser()
    config["Connection"] = {
        "IPAddress": ip_address.strip(),
        "LastFolder": last_folder.strip()
    }
    try:
        with open(INI_FILE, "w") as configfile:
            config.write(configfile)
    except Exception as e:
        print(f"Error: Could not save configuration to file: {e}")

# ==========================================
# BACKEND TEKTRONIX FILESYSTEM LOGIC
# ==========================================
class MSO5Backend:
    def __init__(self):
        self.rm = None
        self.scope = None
        
    def connect_via_ip(self, ip_address):
        """Formats the IP into a standard VXI-11 VISA string and connects."""
        resource_string = f"TCPIP::{ip_address.strip()}::INSTR"
        
        self.rm = pyvisa.ResourceManager()
        self.scope = self.rm.open_resource(resource_string)
        self.scope.timeout = 15000  # 15 seconds generous file timeout
        self.scope.read_termination = None
        self.scope.write_termination = None
        return self.scope.query("*IDN?").strip()

    def disconnect(self):
        """Safely terminates the connection."""
        if self.scope:
            self.scope.close()
        if self.rm:
            self.rm.close()

    def get_cwd(self):
        return self.scope.query("FILESystem:CWD?").strip().strip('"')

    def change_dir(self, path):
        self.scope.write(f'FILESystem:CWD "{path}"')
        return self.get_cwd()

    def list_directory(self):
        raw_dir = self.scope.query("FILESystem:DIR?")
        if not raw_dir or raw_dir.strip() == "":
            return []
        items = [item.strip().strip('"') for item in raw_dir.split(",")]
        return [i for i in items if i]

    def download_file(self, scope_filename, local_destination_path):
        self.scope.write(f'FILESystem:READFile "{scope_filename}"')
        file_data = self.scope.read_raw()
        
        # Parse standard IEEE 488.2 block data
        if file_data.startswith(b'#'):
            num_digits = int(file_data[1:2])
            length = int(file_data[2:2+num_digits])
            header_offset = 2 + num_digits
            actual_data = file_data[header_offset:header_offset+length]
        else:
            actual_data = file_data

        with open(local_destination_path, "wb") as f:
            f.write(actual_data)

    def upload_file(self, local_filepath, scope_destination_name):
        with open(local_filepath, "rb") as f:
            file_data = f.read()
            
        data_len = len(file_data)
        len_str = str(data_len)
        header = f"#{len(len_str)}{len_str}".encode('utf-8')
        
        cmd = f'FILESystem:WRITEFile "{scope_destination_name}",'.encode('utf-8')
        payload = cmd + header + file_data
        
        self.scope.write_raw(payload)
        self.scope.query("*OPC?")


# ==========================================
# TKINTER GRAPHICAL USER INTERFACE (GUI)
# ==========================================
class MSO5GuiApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Tektronix MSO5 Network File Explorer")
        self.root.geometry("650x520")
        self.root.minsize(550, 420)
        
        self.backend = MSO5Backend()
        self.is_connected = False
        
        # Load local settings tracking history
        self.saved_settings = load_settings()
        
        self.build_ui()
        
    def build_ui(self):
        # --- Connection Frame ---
        conn_frame = ttk.LabelFrame(self.root, text=" Network Connection ", padding=10)
        conn_frame.pack(fill="x", padx=10, pady=5)
        
        ttk.Label(conn_frame, text="Scope IP Address:").pack(side="left", padx=2)
        self.ip_entry = ttk.Entry(conn_frame, width=25)
        # Pull initial address value straight out of loaded settings storage
        self.ip_entry.insert(0, self.saved_settings["ip"]) 
        self.ip_entry.pack(side="left", padx=5)
        
        self.btn_connect = ttk.Button(conn_frame, text="Connect", command=self.toggle_connection)
        self.btn_connect.pack(side="left", padx=5)

        # --- Directory Browser Frame ---
        browser_frame = ttk.LabelFrame(self.root, text=" Scope File Browser ", padding=10)
        browser_frame.pack(fill="both", expand=True, padx=10, pady=5)
        
        # Path Bar Subframe
        path_frame = ttk.Frame(browser_frame)
        path_frame.pack(fill="x", pady=2)
        
        ttk.Label(path_frame, text="Current Path:").pack(side="left", padx=2)
        self.path_entry = ttk.Entry(path_frame)
        self.path_entry.pack(side="left", fill="x", expand=True, padx=5)
        self.path_entry.bind("<Return>", lambda event: self.on_path_manual_enter())
        
        self.btn_go = ttk.Button(path_frame, text="Go/Refresh", command=self.refresh_directory, state="disabled")
        self.btn_go.pack(side="left", padx=2)
        
        # File Listbox with Scrollbar
        list_frame = ttk.Frame(browser_frame)
        list_frame.pack(fill="both", expand=True, pady=5)
        
        self.scrollbar = ttk.Scrollbar(list_frame, orient="vertical")
        self.file_listbox = tk.Listbox(list_frame, yscrollcommand=self.scrollbar.set, font=("Courier", 10))
        self.scrollbar.config(command=self.file_listbox.yview)
        
        self.scrollbar.pack(side="right", fill="y")
        self.file_listbox.pack(side="left", fill="both", expand=True)
        self.file_listbox.bind("<Double-1>", lambda event: self.on_item_double_click())
        
        # --- File Actions Frame ---
        actions_frame = ttk.Frame(self.root, padding=10)
        actions_frame.pack(fill="x", padx=10, pady=5)
        
        self.btn_download = ttk.Button(actions_frame, text="📥 Download Selected", command=self.download_action, state="disabled")
        self.btn_download.pack(side="left", padx=5, expand=True, fill="x")
        
        self.btn_upload = ttk.Button(actions_frame, text="📤 Upload File Here", command=self.upload_action, state="disabled")
        self.btn_upload.pack(side="left", padx=5, expand=True, fill="x")

        # --- Status Bar ---
        self.status_var = tk.StringVar(value="Status: Disconnected")
        status_bar = ttk.Label(self.root, textvariable=self.status_var, relief="sunken", anchor="w", padding=3)
        status_bar.pack(side="bottom", fill="x")


    def toggle_connection(self):
        if not self.is_connected:
            ip = self.ip_entry.get().strip()
            if not ip:
                messagebox.showwarning("Input Required", "Please enter a valid IP address first.")
                return
                
            try:
                idn = self.backend.connect_via_ip(ip)
                self.is_connected = True
                self.btn_connect.config(text="Disconnect")
                self.ip_entry.config(state="disabled")
                self.set_ui_state("normal")
                self.status_var.set(f"Connected to: {idn}")
                
                # Try jumping directly back to the last used scope directory automatically
                if self.saved_settings["folder"]:
                    try:
                        self.backend.change_dir(self.saved_settings["folder"])
                    except Exception:
                        pass # Roll back quietly to instrument root default if folder no longer exists
                
                # Fetch directory elements
                self.refresh_directory()
            except Exception as e:
                messagebox.showerror("Network Connection Error", f"Could not connect via network to {ip}:\n\n{e}")
        else:
            try:
                # Capture properties and save current session history out onto your disk before breaking context
                current_ip = self.ip_entry.get().strip()
                current_folder = self.backend.get_cwd()
                save_settings(current_ip, current_folder)
                
                self.backend.disconnect()
            except:
                pass
            self.is_connected = False
            self.btn_connect.config(text="Connect")
            self.ip_entry.config(state="normal")
            self.set_ui_state("disabled")
            self.file_listbox.delete(0, tk.END)
            self.path_entry.delete(0, tk.END)
            self.status_var.set("Status: Disconnected")

    def set_ui_state(self, state_string):
        """Helper to enable or disable interaction widgets."""
        self.btn_go.config(state=state_string)
        self.btn_download.config(state=state_string)
        self.btn_upload.config(state=state_string)

    def refresh_directory(self):
        try:
            cwd = self.backend.get_cwd()
            self.path_entry.delete(0, tk.END)
            self.path_entry.insert(0, cwd)
            
            items = self.backend.list_directory()
            self.file_listbox.delete(0, tk.END)
            
            self.file_listbox.insert(tk.END, "[ .. (Go Up Directory) ]")
            
            for item in items:
                if item.endswith("/") or item.endswith("\\") or ":" in item:
                    self.file_listbox.insert(tk.END, f"📁 {item}")
                else:
                    self.file_listbox.insert(tk.END, f"📦 {item}")
                    
            # Proactively snapshot states to persistent tracking configuration files
            save_settings(self.ip_entry.get().strip(), cwd)
        except Exception as e:
            messagebox.showerror("Error", f"Failed to read directory items:\n{e}")

    def on_path_manual_enter(self):
        if not self.is_connected: return
        target_path = self.path_entry.get().strip()
        try:
            self.backend.change_dir(target_path)
            self.refresh_directory()
        except Exception as e:
            messagebox.showerror("Navigation Error", f"Could not move to specified directory:\n{e}")

    def on_item_double_click(self):
        if not self.is_connected: return
        selection = self.file_listbox.curselection()
        if not selection: return
        
        selected_text = self.file_listbox.get(selection)
        original_cwd = self.backend.get_cwd()
        
        if "[ .. " in selected_text:
            if original_cwd.endswith(":/") or original_cwd.endswith(":\\") or len(original_cwd) <= 3:
                return
            parent = os.path.dirname(original_cwd.rstrip('/\\'))
            if not parent or parent == "":
                parent = original_cwd[:3] 
            self.backend.change_dir(parent)
            self.refresh_directory()
            return

        clean_item = selected_text.replace("📁 ", "").replace("📦 ", "").strip()
        
        try:
            if ":" in clean_item and (clean_item.endswith("/") or clean_item.endswith("\\")):
                self.backend.change_dir(clean_item)
            else:
                separator = "/" if not original_cwd.endswith("/") else ""
                self.backend.change_dir(f"{original_cwd}{separator}{clean_item}")
            
            self.refresh_directory()
            
        except Exception:
            try:
                self.backend.change_dir(original_cwd)
            except:
                pass
            self.download_action()

    def download_action(self):
        selection = self.file_listbox.curselection()
        if not selection:
            messagebox.showwarning("Selection Required", "Please select a file from the list box first.")
            return
        
        selected_text = self.file_listbox.get(selection)
        if "[ .." in selected_text:
            return
            
        filename = selected_text.replace("📁 ", "").replace("📦 ", "").strip()
        local_dest = filedialog.asksaveasfilename(initialfile=filename, title="Save downloaded scope file to PC")
        
        if local_dest:
            self.status_var.set(f"Downloading {filename}...")
            self.root.update_idletasks()
            try:
                self.backend.download_file(filename, local_dest)
                self.status_var.set("Download completed successfully!")
                messagebox.showinfo("Success", f"'{filename}' downloaded successfully!")
            except Exception as e:
                self.status_var.set("Download failed.")
                messagebox.showerror("Transfer Error", f"Failed to download file:\n{e}\n\nNote: If this item is a folder, it cannot be downloaded directly.")
            self.refresh_directory()

    def upload_action(self):
        local_src = filedialog.askopenfilename(title="Select file from PC to upload")
        if not local_src:
            return
            
        filename = os.path.basename(local_src)
        self.status_var.set(f"Uploading {filename} to scope...")
        self.root.update_idletasks()
        try:
            self.backend.upload_file(local_src, filename)
            self.status_var.set("Upload completed successfully!")
            messagebox.showinfo("Success", f"'{filename}' uploaded successfully!")
            self.refresh_directory()
        except Exception as e:
            self.status_var.set("Upload failed.")
            messagebox.showerror("Transfer Error", f"Failed to upload file:\n{e}")

# ==========================================
# MAIN EXECUTION ENTRY POINT
# ==========================================
if __name__ == "__main__":
    root = tk.Tk()
    app = MSO5GuiApp(root)
    
    def on_close_window():
        try:
            # Capture properties and save current session data to file upon clicking the close 'X' button
            if app.is_connected:
                current_ip = app.ip_entry.get().strip()
                current_folder = app.backend.get_cwd()
                save_settings(current_ip, current_folder)
            app.backend.disconnect()
        except:
            pass
        root.destroy()
        
    root.protocol("WM_DELETE_WINDOW", on_close_window)
    root.mainloop()
