#!/usr/bin/env python3
"""
Setup script to install gitingest in a virtual environment for VoiceInk
Run this script during build or first launch to set up the Python environment
"""

import subprocess
import sys
import os
from pathlib import Path

def setup_gitingest_environment():
    """Set up a virtual environment with gitingest for VoiceInk"""
    
    # Determine the target directory (where this script is located)
    script_dir = Path(__file__).parent
    venv_dir = script_dir / "python-env"
    
    print(f"Setting up GitIngest environment in: {venv_dir}")
    
    try:
        # Create virtual environment
        print("Creating virtual environment...")
        subprocess.run([
            sys.executable, "-m", "venv", str(venv_dir)
        ], check=True)
        
        # Determine python and pip paths in venv
        if sys.platform == "win32":
            python_path = venv_dir / "Scripts" / "python.exe"
            pip_path = venv_dir / "Scripts" / "pip.exe"
        else:
            python_path = venv_dir / "bin" / "python"
            pip_path = venv_dir / "bin" / "pip"
        
        # Upgrade pip
        print("Upgrading pip...")
        subprocess.run([
            str(pip_path), "install", "--upgrade", "pip"
        ], check=True)
        
        # Install gitingest
        print("Installing gitingest...")
        subprocess.run([
            str(pip_path), "install", "gitingest"
        ], check=True)
        
        # Verify installation
        print("Verifying installation...")
        result = subprocess.run([
            str(python_path), "-c", "import gitingest; print('GitIngest installed successfully')"
        ], capture_output=True, text=True)
        
        if result.returncode == 0:
            print("✅ GitIngest environment setup completed successfully!")
            print(f"Python path: {python_path}")
            print(f"GitIngest version: {get_gitingest_version(str(python_path))}")
        else:
            print("❌ Installation verification failed:")
            print(result.stderr)
            return False
            
    except subprocess.CalledProcessError as e:
        print(f"❌ Setup failed: {e}")
        return False
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return False
    
    return True

def get_gitingest_version(python_path):
    """Get the installed gitingest version"""
    try:
        result = subprocess.run([
            python_path, "-c", "import gitingest; print(getattr(gitingest, '__version__', 'unknown'))"
        ], capture_output=True, text=True)
        return result.stdout.strip() if result.returncode == 0 else "unknown"
    except:
        return "unknown"

def main():
    print("VoiceInk GitIngest Environment Setup")
    print("=" * 40)
    
    if setup_gitingest_environment():
        print("\n🎉 Setup completed! VoiceInk can now use GitIngest.")
    else:
        print("\n💥 Setup failed. Please check the error messages above.")
        sys.exit(1)

if __name__ == "__main__":
    main()