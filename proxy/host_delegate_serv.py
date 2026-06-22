import json
import subprocess
import argparse
from http.server import HTTPServer, BaseHTTPRequestHandler

class CommandHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            response_data = {
                "status": "ok"
            }
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(response_data).encode('utf-8'))

    def do_POST(self):
        if self.path == '/run':
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)

            try:
                data = json.loads(post_data.decode('utf-8'))
                command = data.get('command', '')
                # Support args as a list or a string
                args = data.get('args', [])
                
                # Construct the execution list, e.g. ["ls", "-l", "/tmp/folder name"]
                if isinstance(args, str):
                    # If user passes a string, split it with shlex (optional) or put it directly into the list
                    import shlex
                    full_command = [command] + shlex.split(args)
                else:
                    # If user passes a list, concatenate it directly
                    full_command = [command] + args

                # Execute the command (not using shell=True is safer and handles arguments more precisely)
                result = subprocess.run(
                    full_command,
                    capture_output=True,
                    text=True,
                    timeout=30
                )

                response_data = {
                    "stdout": result.stdout,
                    "stderr": result.stderr,
                    "exitcode": result.returncode
                }
                status_code = 200

            except FileNotFoundError:
                response_data = {"error": f"Command '{command}' not found"}
                status_code = 404
            except json.JSONDecodeError:
                response_data = {"error": "Invalid JSON"}
                status_code = 400
            except Exception as e:
                response_data = {"error": str(e)}
                status_code = 500

            self.send_response(status_code)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(response_data).encode('utf-8'))
        else:
            self.send_error(404)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--host', type=str, default='0.0.0.0')
    parser.add_argument('--port', type=int, default=28789)
    args = parser.parse_args()

    print(f"🚀 Server ready at http://{args.host}:{args.port}")
    HTTPServer((args.host, args.port), CommandHandler).serve_forever()

if __name__ == '__main__':
    main()