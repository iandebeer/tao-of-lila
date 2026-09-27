"""Persona HTTP acceptance against an explicitly supplied disposable API."""
import json
import sys
import time
import urllib.request
import urllib.error

base = sys.argv[1]
token = None

def request(path, method='GET', body=None, expected=200):
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(base + path, data=None if body is None else json.dumps(body).encode(), headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as response:
            status, value = response.status, json.load(response)
    except urllib.error.HTTPError as error:
        status, value = error.code, json.load(error)
    assert status == expected, (path, status, value)
    return value

account = {'authUsername': 'persona_test_' + str(time.time_ns()), 'authPassword': 'disposable-persona-test'}
token = request('/auth/register', 'POST', account)['authToken']
assert request('/personas') == []
request('/journey-session', expected=409)
draft = {'draftName': 'Constructed scholar', 'draftDescription': 'An elderly fictional scholar', 'draftAttributes': [], 'draftContext': 'Community responsibilities', 'draftAvatar': None, 'draftRevision': None}
a = request('/personas', 'POST', draft)
b = request('/personas', 'POST', dict(draft, draftName='Wanderer'))
assert len(request('/personas')) == 2
request(f"/personas/{a['personaId']}/select", 'POST')
journey_a = request('/journey-session')
assert journey_a['game']['gameJourney']['journeyPersonaId'] == a['personaId']
request('/game/question', 'POST', {'requestedQuestionText': 'A question for the scholar'})
request(f"/personas/{b['personaId']}/journey", 'POST')
assert request('/game')['gameQuestion'] is None
updated = request(f"/personas/{a['personaId']}", 'PUT', dict(draft, draftDescription='Later context', draftRevision=0))
assert updated['personaInitialDescription'] == draft['draftDescription']
assert request(f"/personas/{b['personaId']}") == b
context = request(f"/personas/{a['personaId']}/question-context")
assert 'fictional or constructed persona' in context['personaContext']
assert account['authUsername'] not in json.dumps(context)
request(f"/personas/{a['personaId']}", 'DELETE')
request(f"/personas/{a['personaId']}/select", 'POST', expected=409)
assert request('/game')['gameJourney']['journeyPersonaId'] == b['personaId']
assert request(f"/personas/{a['personaId']}/history")
token = request('/auth/register', 'POST', dict(account, authUsername=account['authUsername'] + '_other'))['authToken']
request(f"/personas/{b['personaId']}", expected=404)
request(f"/personas/{b['personaId']}/select", 'POST', expected=404)
print('PASS: Persona HTTP creation, selection, resume, editing, privacy, archive and ownership isolation')
