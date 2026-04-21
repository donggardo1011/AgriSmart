import requests
import json

# Get auth token first
print("Testing API at http://localhost:8000")
login_response = requests.post('http://localhost:8000/auth/login', json={
    'username': 'edgarestenzo',
    'password': 'admin123',
    'recaptcha_token': 'test_token_dev'
})

print(f'Login status: {login_response.status_code}')
if login_response.status_code == 200:
    token = login_response.json()['access_token']
    print('✅ Auth successful')
    
    # Get diseases
    response = requests.get('http://localhost:8000/api/diseases', headers={
        'Authorization': f'Bearer {token}'
    })
    
    print(f'Diseases status: {response.status_code}')
    if response.status_code == 200:
        diseases = response.json()
        print(f'Total diseases: {len(diseases)}')
        if diseases:
            disease = diseases[0]
            print(f'\n📊 First disease (complete JSON):')
            print(json.dumps(disease, indent=2))
    else:
        print(f'Diseases error: {response.status_code} - {response.text}')
else:
    print(f'Login error: {login_response.status_code} - {login_response.text}')
