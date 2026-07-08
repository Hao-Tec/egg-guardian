"""
Script to generate Google OAuth Refresh Token for Egg Guardian.
This script requires a credentials.json file downloaded from Google Cloud Console.

Usage:
1. Go to Google Cloud Console -> APIs & Services -> Credentials
2. Create Credentials -> OAuth client ID
3. Application type: Desktop app
4. Download JSON and save as `credentials.json` in the root directory.
5. Run this script: python scripts/get_google_token.py
"""

import os
from google_auth_oauthlib.flow import InstalledAppFlow

# Scope required to send emails via Gmail API
SCOPES = ['https://www.googleapis.com/auth/gmail.send']

def main():
    creds_file = 'credentials.json'
    if not os.path.exists(creds_file):
        print(f"Error: {creds_file} not found.")
        print("Please download your OAuth client ID JSON from Google Cloud Console")
        print("and save it as 'credentials.json' in the root directory.")
        return

    print("Initializing OAuth flow...")
    print("A browser window will open asking you to log in to your Google Account.")
    print("Make sure you log in with the email address you intend to send alerts from.")
    print("-" * 60)

    try:
        flow = InstalledAppFlow.from_client_secrets_file(creds_file, SCOPES)
        creds = flow.run_local_server(port=0)

        print("\n" + "=" * 60)
        print("🎉 SUCCESS! Authorization complete.")
        print("=" * 60)
        print("\nPlease copy the following values into your .env file:")
        print(f"GOOGLE_CLIENT_ID={creds.client_id}")
        print(f"GOOGLE_CLIENT_SECRET={creds.client_secret}")
        print(f"GOOGLE_REFRESH_TOKEN={creds.refresh_token}")
        print("=" * 60)

    except Exception as e:
        print(f"\nAn error occurred: {e}")

if __name__ == '__main__':
    main()
