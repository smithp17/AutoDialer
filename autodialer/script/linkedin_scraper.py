import warnings
warnings.filterwarnings("ignore")

import os
from dotenv import load_dotenv
from bs4 import BeautifulSoup
from selenium import webdriver
from selenium.webdriver.common.by import By
from time import sleep
import json

# Load environment variables from .env file
load_dotenv()

# Get credentials from .env file
EMAIL = os.getenv('EMAIL')
PASSWORD = os.getenv('PASSWORD')

# List of 20 random LinkedIn profile usernames to scrape
profile_usernames = [
    "laxmimerit", "satyanadella", "jeffweiner08", "williamhgates", "reidhoffman",
    "shreyas", "naval", "paulg", "elonmusk", "markzuckerberg",
    "sherylsandberg", "sundarpicha", "timcook", "aaronlevie", "dharmesh",
    "brianchesky", "nathanblecharczyk", "sidkumar", "adamgrant", "simonssinek"
]

def scrape_profile(driver, username):
    profile_data = {}
    
    url = f"https://www.linkedin.com/in/{username}"
    driver.get(url)
    sleep(4)
    
    # Get page source
    page_source = driver.page_source
    soup = BeautifulSoup(page_source, 'html.parser')
    
    # Extract Name - Multiple attempts with different selectors
    name = ""
    try:
        # Try selector 1
        name_elem = soup.find('h1', {'class': lambda x: x and 'text-heading-xlarge' in x})
        if name_elem:
            name = name_elem.get_text().strip()
    except:
        pass
    
    if not name:
        try:
            # Try selector 2
            name_elem = soup.find('h1')
            if name_elem:
                name = name_elem.get_text().strip()
        except:
            pass
    
    if not name:
        try:
            # Try selector 3 - look for span with profile name
            name_spans = soup.find_all('span', {'class': 'visually-hidden'})
            if name_spans:
                name = name_spans[0].get_text().strip()
        except:
            pass
    
    profile_data['name'] = name
    profile_data['url'] = url
    
    # Extract Headline - Multiple attempts
    headline = ""
    try:
        # Try selector 1
        headline_elem = soup.find('div', {'class': lambda x: x and 'text-body-medium' in x})
        if headline_elem:
            headline = headline_elem.get_text().strip()
    except:
        pass
    
    if not headline:
        try:
            # Try selector 2
            headline_elem = soup.find('div', {'class': lambda x: x and 'break-words' in x})
            if headline_elem:
                headline = headline_elem.get_text().strip()
        except:
            pass
    
    if not headline:
        try:
            # Try selector 3 - look in profile headline section
            headline_divs = soup.find_all('div')
            for div in headline_divs:
                text = div.get_text().strip()
                if len(text) > 10 and len(text) < 200 and '@' not in text:
                    headline = text
                    break
        except:
            pass
    
    profile_data['headline'] = headline
    
    # About Section - Multiple attempts
    about = ""
    try:
        # Try clicking show more button first
        try:
            show_more_btn = driver.find_element(By.CLASS_NAME, "inline-show-more-text__button")
            driver.execute_script("arguments[0].click();", show_more_btn)
            sleep(2)
            page_source = driver.page_source
            soup = BeautifulSoup(page_source, 'html.parser')
        except:
            pass
        
        # Try selector 1
        about_elem = soup.find('div', {'class': lambda x: x and 'display-flex' in x and 'ph5' in x})
        if about_elem:
            about = about_elem.get_text().strip()
    except:
        pass
    
    if not about:
        try:
            # Try selector 2 - look for about section
            about_divs = soup.find_all('div')
            for div in about_divs:
                if div.get('id') == 'about':
                    about = div.get_text().strip()
                    break
        except:
            pass
    
    if not about:
        try:
            # Try selector 3 - find text that looks like about content
            all_text = soup.get_text()
            if 'About' in all_text:
                about = all_text.split('About')[1][:500] if 'About' in all_text else ""
        except:
            pass
    
    profile_data['about'] = about
    
    return profile_data

def main():
    # Check if credentials are loaded
    if not EMAIL or not PASSWORD:
        print(" Error: EMAIL or PASSWORD not found in .env file")
        print("Make sure your .env file contains:")
        print("EMAIL=your_email@example.com")
        print("PASSWORD=your_password")
        return
    
    # Initialize driver
    driver = webdriver.Chrome()
    
    try:
        # Login to LinkedIn
        print(" Logging in to LinkedIn...")
        driver.get('https://www.linkedin.com/login')
        sleep(2)
        
        email = driver.find_element(By.ID, 'username')
        email.send_keys(EMAIL)
        
        password = driver.find_element(By.ID, 'password')
        password.send_keys(PASSWORD)
        
        password.submit()
        sleep(5)
        
        # Scrape 20 profiles
        all_profiles = []
        
        print(f"Starting to scrape {len(profile_usernames)} profiles...\n")
        
        for idx, username in enumerate(profile_usernames, 1):
            print(f"[{idx}/20] Scraping profile: {username}")
            try:
                profile_data = scrape_profile(driver, username)
                all_profiles.append(profile_data)
                print(f" Name: {profile_data.get('name', 'N/A')}")
                print(f" Headline: {profile_data.get('headline', 'N/A')[:80]}...")
                print(f" Successfully scraped: {username}\n")
            except Exception as e:
                print(f" Error scraping {username}: {str(e)}\n")
            
            sleep(3)  # Wait between requests
        
        # Save to JSON
        with open('scraped_profiles.json', 'w', encoding='utf-8') as f:
            json.dump(all_profiles, f, indent=4, ensure_ascii=False)
        
        print(f"\nTotal profiles scraped: {len(all_profiles)}")
        print(" Data saved to scraped_profiles.json")
        
    except Exception as e:
        print(f"An error occurred: {str(e)}")
    
    finally:
        driver.quit()
        print("Browser closed")

if __name__ == "__main__":
    main()
