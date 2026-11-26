import json
import http.client
import runpy
import threading
from concurrent.futures import ThreadPoolExecutor
from http.server import HTTPServer
from pathlib import Path
from unittest.mock import patch

module = runpy.run_path(str(Path(__file__).resolve().parents[2] / 'bin/t3-9router-quota'))
snapshot = module['snapshot']


def fixture(path):
    if path == '/api/providers':
        return {'connections': [
            {'id': 'one', 'provider': 'claude'}, {'id': 'two', 'provider': 'antigravity'},
            {'id': 'three', 'provider': 'codex', 'email': 'one@example.test',
             'accessToken': 'private', 'providerSpecificData': {'chatgptAccountId': 'workspace'}},
            {'id': 'off', 'provider': 'codex', 'isActive': False},
            {'id': 'unreachable', 'provider': 'codex'}
        ]}
    if path == '/api/usage/unreachable':
        raise ConnectionError()
    if path == '/api/usage/one':
        return {'quotas': {'weekly (7d)': {'used': 5, 'total': 20, 'resetAt': '2026-12-01T00:00:00Z'},
                           'weekly fable (7d)': {'used': 9, 'total': 100},
                           'undisclosed': {'total': 0}, 'unlimited': {'unlimited': True, 'used': 0, 'total': 100}}}
    if path == '/api/usage/two':
        return {'quotas': {'model-a': {'remainingPercentage': 33.5, 'resetAt': None}}}
    if path == '/api/usage/three':
        return {'plan': 'pro', 'quotas': {'weekly': {'used': 4, 'total': 10, 'resetAt': '2026-12-01T00:00:00Z'},
                                          'review_weekly': {'used': 99, 'total': 100}}}
    raise AssertionError(path)


with patch.dict(snapshot.__globals__, router_get=fixture), ThreadPoolExecutor(max_workers=1) as worker:
    with HTTPServer(('127.0.0.1', 0), module['Feed']) as server:
        server.authorization = b'Bearer fixture'
        server.worker = worker
        server.refresh = None
        thread = threading.Thread(target=server.serve_forever)
        thread.start()

        def request(method, path, body=None, auth='Bearer fixture'):
            conn = http.client.HTTPConnection(*server.server_address, timeout=5)
            try:
                conn.request(method, path, json.dumps(body) if body else None, {'Authorization': auth})
                response = conn.getresponse()
                data = response.read()
                return response.status, json.loads(data) if data else None
            finally:
                conn.close()

        def usage(key, url, method='GET'):
            return request('POST', '/v0/management/api-call', {'auth_index': key, 'method': method, 'url': url})

        try:
            path = '/v0/management/auth-files'
            assert request('GET', path, auth='')[0] == 401
            assert request('POST', '/v0/management/api-call', auth='')[0] == 401
            status, listing = request('GET', path)
            assert status == 200
            assert listing['files'] == [
                {'id': 'one', 'auth_index': 'one', 'provider': 'claude'},
                {'id': 'three', 'auth_index': 'three', 'provider': 'codex', 'email': 'one@example.test',
                 'id_token': {'chatgpt_account_id': 'workspace'}},
                {'id': 'unreachable', 'auth_index': 'unreachable', 'provider': 'codex'},
            ]
            codex = 'https://chatgpt.com/backend-api/wham/usage'
            claude = 'https://api.anthropic.com/api/oauth/usage'
            for key, url, expected in [
                ('three', codex, {'plan_type': 'pro', 'rate_limit': {
                    'secondary_window': {'used_percent': 40, 'reset_at': 1796083200}}}),
                ('one', claude, {'seven_day': {'utilization': 25, 'resets_at': '2026-12-01T00:00:00Z'},
                                 'limits': [{'kind': 'weekly_scoped', 'percent': 9, 'resets_at': None,
                                             'scope': {'model': {'display_name': 'Fable'}}}]}),
            ]:
                status, response = usage(key, url)
                assert status == response['status_code'] == 200
                assert json.loads(response['body']) == expected
            assert usage('three', claude)[0] == usage('unreachable', codex)[0] == 404
            assert usage('three', codex, method='POST')[0] == usage('three', 'https://example.test')[0] == 404
            status, feed = request('GET', '/quotas')
            assert status == 200 and feed['version'] == 1
            claude_account, google, codex_account = feed['accounts']
            assert claude_account['providerInstanceId'] == 'claudeAgent'
            assert [w['usedPercent'] for w in claude_account['windows']] == [25, 9]
            assert google['windows'] == [{'id': 'model-a', 'kind': 'other', 'label': 'model-a', 'usedPercent': 66.5}]
            assert codex_account['providerInstanceId'] == 'codex'
        finally:
            server.shutdown()
            thread.join()
