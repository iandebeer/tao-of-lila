"""Opt-in acceptance against a disposable local database/API (no AI calls).

Run with: python3 scripts/journey-api-test.py http://127.0.0.1:8080
Creates one uniquely named test account; use only a disposable database.
"""
import json
import secrets
import sys
import urllib.error
import urllib.request

base = sys.argv[1] if len(sys.argv) > 1 else 'http://127.0.0.1:8080'
token = None


def request(path, body=None, expected=200):
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(base + path, data=json.dumps(body).encode() if body is not None else None, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=20) as response:
            assert response.status == expected, response.status
            return json.load(response)
    except urllib.error.HTTPError as error:
        assert error.code == expected, (error.code, error.read().decode())
        return json.load(error)


auth = request('/auth/register', {'authUsername': 'journey_test_' + secrets.token_hex(5), 'authPassword': secrets.token_urlsafe(24)})
token = auth['authToken']
persona = request('/personas', {'draftName': 'Journey acceptance', 'draftDescription': 'A fictional test traveller', 'draftAttributes': [], 'draftContext': 'Disposable integration test', 'draftAvatar': None, 'draftRevision': None})
request(f"/personas/{persona['personaId']}/select", {})
state = request('/journey-session')


def command(action, text=None, visual=None):
    global state
    state = request('/journey-session', {'expectedRevision': state['workflow']['workflowRevision'], 'commandAction': action, 'commandText': text, 'commandVisual': visual})
    return state


command('question')
command('draft', 'What does persistence preserve?')
assert request('/journey-session')['workflow']['workflowQuestion'] == 'What does persistence preserve?'
command('begin')
origin = state['game']['gameJourney']['journeyCurrentStateId']
old_revision = state['workflow']['workflowRevision']
command('next')
request('/journey-session', {'expectedRevision': old_revision, 'commandAction': 'next', 'commandText': None, 'commandVisual': None}, 409)
assert request('/journey-session')['workflow']['workflowCasting'] == state['workflow']['workflowCasting']
request('/game/casting/new', {}, 409)
for _ in range(150):
    if state['workflow']['workflowCasting']['result']:
        break
    command('next')
else:
    raise AssertionError('Casting did not finish')
command('result')
assert len(state['history']) == 1
assert state['history'][0]['rawCasting']['completedLines'] == state['workflow']['workflowCasting']['completedLines']
assert state['game']['gameJourney']['journeyCurrentStateId'] == origin
command('interpretation')
command('reflection')
command('journal', 'A durable reflection.\nWith a second line.')
assert request('/journey-session')['workflow']['workflowJournal'] == 'A durable reflection.\nWith a second line.'
command('movement', 'A durable reflection.\nWith a second line.')
target = state['movement']['final']['stateId']
command('acknowledge')
assert state['game']['gameJourney']['journeyCurrentStateId'] == target
assert state['game']['gameJourney']['journeyPreviousStateId'] == origin
assert state['workflow']['workflowStage'] == 'progress'
assert len(state['history']) == 1
command('question')
assert state['workflow']['workflowQuestion'] == ''
print('PASS: authentication, question recovery, stale Next, prototype lock, six lines, raw history, journal recovery, deferred movement, next cycle')
