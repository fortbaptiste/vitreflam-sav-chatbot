#!/usr/bin/env python3
"""
VITREFLAM - Lancer le serveur
Usage: python run.py
"""

import subprocess
import sys
import os

def main():
    # Se placer dans le bon dossier
    os.chdir(os.path.dirname(os.path.abspath(__file__)))

    print("\n" + "="*60)
    print("   VITREFLAM SAV - Demarrage")
    print("="*60 + "\n")

    # Lancer uvicorn
    subprocess.run([
        sys.executable, "-m", "uvicorn",
        "app.main:app",
        "--host", "0.0.0.0",
        "--port", os.environ.get("PORT", "8000")
    ])

if __name__ == "__main__":
    main()
