import requests
import json

# Get auth token first
login_response = requests.post('http://localhost:8000/auth/login', json={
    'username': 'edgarestenzo',
    'password': 'admin123',
    'recaptcha_token': 'test_token_dev'
})

if login_response.status_code == 200:
    token = login_response.json()['access_token']
    print('✅ Auth successful')
    
    # Test chatbot with symptoms question
    response = requests.post('http://localhost:8000/api/chatbot', headers={
        'Authorization': f'Bearer {token}'
    }, json={
        'disease': 'sheath_blight',
        'message': 'What symptoms should I watch for?',
        'language': 'english'
    })
    
    if response.status_code == 200:
        data = response.json()
        print('\n📊 Chatbot Response:')
        print(data['reply'])
        print('\n' + '='*60)
        
        # Test fertilizer guidance
        response2 = requests.post('http://localhost:8000/api/chatbot', headers={
            'Authorization': f'Bearer {token}'
        }, json={
            'disease': 'sheath_blight',
            'message': 'What fertilizer guidance should I follow?',
            'language': 'english'
        })
        
        if response2.status_code == 200:
            data2 = response2.json()
            print('\n💊 Fertilizer Guidance Response:')
            print(data2['reply'])
    else:
        print(f'Chatbot error: {response.status_code}')
else:
    print(f'Login error: {login_response.status_code}')
