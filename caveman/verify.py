#!/usr/bin/env python3
"""Check live compression and exact MCP recovery using synthetic tool output."""
import json
import os
from pathlib import Path
import re
import select
import subprocess
import urllib.request

HOME_DIR = Path.home()
STATE = HOME_DIR / '.local/state/caveman'
BINARY = HOME_DIR / '.local/share/caveman/bin-v1.1.7/caveman-mcp'
BASE = 'http://127.0.0.1:8787/compat/quotio/v1'
LOG = ''.join(f'INFO task={i:04d} status=complete Build validation completed successfully; no changes required.\n' for i in range(600))
LOG += 'ERROR CAVEMAN_DEPLOY_927 exit code 72 at /src/alpha.ts:41\n'
env = os.environ | {'CAVEMAN_HOME': str(STATE), 'CAVEMAN_CCR_DB': str(STATE / 'ccr.db')}


def rpc(proc, ident, method, params):
    proc.stdin.write(json.dumps({'jsonrpc': '2.0', 'id': ident, 'method': method, 'params': params}) + '\n')
    proc.stdin.flush()
    assert select.select([proc.stdout], [], [], 20)[0], 'MCP response timed out'
    response = json.loads(proc.stdout.readline())
    assert response.get('id') == ident and 'result' in response, 'MCP request failed'
    return response['result']


def send(protocol, data, headers):
    req = urllib.request.Request(BASE + '/' + protocol, json.dumps(data).encode(), headers)
    with urllib.request.urlopen(req, timeout=120) as response:
        events = [json.loads(line[6:]) for line in response.read().decode().splitlines()
                  if line.startswith('data: {')]
        handle = response.headers.get('x-caveman-recovery-handle', '')
        status = response.status
    assert any(e.get('type') in ['response.completed', 'message_stop'] for e in events), 'Stream did not complete'
    assert not any(e.get('type') in ['error', 'response.failed'] for e in events), 'Provider returned a stream error'
    return status, handle


def main():
    key = subprocess.check_output([str(HOME_DIR / '.config/bin/quotio-client-key')], text=True).strip()
    results = []
    proc = subprocess.Popen([str(BINARY)], env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                            stderr=subprocess.DEVNULL, text=True)
    try:
        rpc(proc, 1, 'initialize', {'protocolVersion': '2024-11-05', 'capabilities': {},
                                  'clientInfo': {'name': 'caveman-deployment-check', 'version': '1'}})
        proc.stdin.write('{"jsonrpc":"2.0","method":"notifications/initialized"}\n')
        proc.stdin.flush()
        tool = next(t for t in rpc(proc, 2, 'tools/list', {})['tools'] if t['name'] == 'caveman_retrieve')
        for protocol in ['responses', 'messages']:
            prompt = 'Report the exact ERROR identifier, exit code, and both active router preference identifiers. No other content.'
            if protocol == 'responses':
                data = {'model': 'gpt-6-luna', 'stream': True, 'max_output_tokens': 1024,
                        'input': [{'role': 'user', 'content': prompt},
                                  {'type': 'function_call', 'name': 'build', 'call_id': 'build_check', 'arguments': '{}'},
                                  {'type': 'function_call_output', 'call_id': 'build_check', 'output': LOG}],
                        'tools': [{'type': 'function', 'name': 'build', 'parameters': {'type': 'object', 'properties': {}}},
                                  {'type': 'function', 'name': 'mcp__caveman__caveman_retrieve',
                                   'description': tool['description'], 'parameters': tool['inputSchema']}]}
                headers = {'Authorization': 'Bearer ' + key}
            else:
                data = {'model': 'claude-haiku-4-5-20251001', 'stream': True, 'max_tokens': 1024,
                        'messages': [{'role': 'user', 'content': prompt},
                                     {'role': 'assistant', 'content': [{'type': 'tool_use', 'id': 'build_check', 'name': 'build', 'input': {}}]},
                                     {'role': 'user', 'content': [{'type': 'tool_result', 'tool_use_id': 'build_check', 'content': LOG}]}],
                        'tools': [{'name': 'build', 'input_schema': {'type': 'object', 'properties': {}}},
                                  {'name': 'mcp__caveman__caveman_retrieve', 'description': tool['description'],
                                   'input_schema': tool['inputSchema']}]}
                headers = {'x-api-key': key, 'anthropic-version': '2023-06-01'}
            headers.update({'Content-Type': 'application/json', 'session_id': 'caveman-deployment-' + protocol})
            status, handle = send(protocol, data, headers)
            assert re.fullmatch(r'ccr_[0-9a-f]+', handle), 'Expected compression and one recovery handle'
            recovered = rpc(proc, 3, 'tools/call', {'name': 'caveman_retrieve', 'arguments': {'recovery_handle': handle}})
            assert ''.join(c.get('text', '') for c in recovered['content']) == LOG, 'Original recovery mismatch'
            result = {'protocol': protocol, 'model': data['model'], 'status': status, 'compressed': True,
                      'exact_recovery': True, 'fixture_handle': handle}
            results.append(result)
            print(json.dumps(result), flush=True)
        return results
    finally:
        proc.stdin.close()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.terminate()
            proc.wait(timeout=5)


if __name__ == '__main__':
    main()
