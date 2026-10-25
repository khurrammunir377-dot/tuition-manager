import requests

url = 'https://gxlwsrrdcbecqcaiwufm.supabase.co'
anon = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd4bHdzcnJkY2JlY3FjYWl3dWZtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5NzA0MzQsImV4cCI6MjA5ODU0NjQzNH0.ABH9WyW3OAC0cynj4qMy1iAEb2qJJFZGzNlTED6zG2A'

headers = {
    'apikey': anon,
    'Authorization': f'Bearer {anon}',
    'Content-Type': 'application/json'
}

print("1. Testing questions table select:")
r1 = requests.get(f'{url}/rest/v1/questions?select=*', headers=headers)
print(f"Status: {r1.status_code}, Body: {r1.text[:200]}")

print("\n2. Testing get_questions RPC:")
r2 = requests.post(f'{url}/rest/v1/rpc/get_questions', json={'p_code': 'test'}, headers=headers)
print(f"Status: {r2.status_code}, Body: {r2.text[:200]}")

print("\n3. Testing ask_question RPC:")
r3 = requests.post(f'{url}/rest/v1/rpc/ask_question', json={'p_code': 'test', 'p_q': 'Hello test'}, headers=headers)
print(f"Status: {r3.status_code}, Body: {r3.text[:200]}")

print("\n4. Testing insert into questions table directly:")
r4 = requests.post(f'{url}/rest/v1/questions', json={'code': 'test', 'q': 'Hello test direct insert'}, headers=headers)
print(f"Status: {r4.status_code}, Body: {r4.text[:200]}")
