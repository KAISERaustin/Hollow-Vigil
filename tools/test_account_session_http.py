"""Verify account restoration across three Godot processes using a local auth fixture."""
import argparse
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import subprocess
import tempfile
import threading

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--godot', required=True)
parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
args = parser.parse_args()
requests = []
errors = []

class AuthFixture(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def do_POST(self):
        payload = json.loads(self.rfile.read(int(self.headers.get('Content-Length', 0))))
        requests.append(self.path)
        valid = self.headers.get('apikey') == 'sb_publishable_fixture'
        if self.path == '/auth/v1/verify':
            valid &= payload == {'token': 'fixture-code'}
            token = 'fixture-refresh'
        elif self.path == '/auth/v1/token?grant_type=refresh_token':
            valid &= payload == {'refresh_token': 'fixture-refresh'}
            token = 'fixture-rotated'
        elif self.path == '/rest/v1/rpc/list_saves':
            valid &= self.headers.get('Authorization') == 'Bearer fixture-access'
            token = None
        else:
            valid = False
            token = None
        if not valid:
            errors.append('Unexpected auth request contract: ' + self.path)
        result = [] if token is None else {
            'access_token': 'fixture-access', 'refresh_token': token, 'expires_in': 3600,
            'user': {'id': '11111111-1111-4111-8111-111111111111',
                     'email': 'fixture@example.invalid',
                     'user_metadata': {'display_name': 'HTTP returning player'}}}
        data = json.dumps(result).encode()
        self.send_response(200 if valid else 400)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

server = ThreadingHTTPServer(('127.0.0.1', 0), AuthFixture)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
try:
    with tempfile.TemporaryDirectory(prefix='vigil-auth-http-') as directory:
        endpoint = 'http://127.0.0.1:' + str(server.server_port)
        for phase in ['sign-in', 'restore', 'signed-out']:
            result = subprocess.run([
                args.godot, '--headless', '--path', str(args.project), '--script',
                'tests/account_session_http_runner.gd', '--', endpoint,
                str(Path(directory) / 'account.json'), phase,
            ], text=True, capture_output=True, timeout=30)
            output = result.stdout + result.stderr
            print(output, end='')
            assert result.returncode == 0 and 'ERROR:' not in output, phase
    assert not errors, errors
    assert requests == ['/auth/v1/verify', '/auth/v1/token?grant_type=refresh_token',
                        '/rest/v1/rpc/list_saves'], requests
    print('PASS: three process lifetimes, real HTTP transport, token rotation, no uploads')
finally:
    server.shutdown()
    server.server_close()
