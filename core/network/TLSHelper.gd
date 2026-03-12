extends Node

## TLSHelper
## Handles generation and loading of TLS certificates for DTLS.

const CERT_PATH = "user://server.crt"
const KEY_PATH = "user://server.key"

var custom_cert_path: String = ""
var custom_key_path: String = ""

func _ready() -> void:
	# Check for CLI overrides (e.g., --cert=/mnt/certs/tls.crt)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cert="):
			custom_cert_path = arg.split("=")[1]
		if arg.begins_with("--key="):
			custom_key_path = arg.split("=")[1]

## Generates a self-signed certificate and key if they don't exist
func ensure_certs() -> void:
	# If external certs are provided via CLI, don't generate anything
	if custom_cert_path != "" and custom_key_path != "":
		if FileAccess.file_exists(custom_cert_path) and FileAccess.file_exists(custom_key_path):
			print("[TLSHelper] Using external certificates provided via CLI.")
			return
		else:
			printerr("[TLSHelper] ERROR: External certs specified but not found!")

	# Fallback to user:// for local dev
	if FileAccess.file_exists(CERT_PATH) and FileAccess.file_exists(KEY_PATH):
		return
		
	print("[TLSHelper] Local: Generating self-signed dev certificates...")
	var crypto = Crypto.new()
	var key = crypto.generate_rsa(2048)
	var cert = crypto.generate_self_signed_certificate(key, "CN=project-lantern,O=DungeonMomo,C=FR")
	
	cert.save(CERT_PATH)
	key.save(KEY_PATH)

func get_server_options() -> TLSOptions:
	var cert = X509Certificate.new()
	var key = CryptoKey.new()
	
	var path_c = custom_cert_path if custom_cert_path != "" else CERT_PATH
	var path_k = custom_key_path if custom_key_path != "" else KEY_PATH
	
	cert.load(path_c)
	key.load(path_k)
	return TLSOptions.server(key, cert)

func get_client_options() -> TLSOptions:
	# If the server uses a REAL CA (from cert-manager/Let's Encrypt), 
	# the client can use standard validation:
	if custom_cert_path != "":
		print("[TLSHelper] Client: Using standard CA validation (Production).")
		return TLSOptions.client()
	
	# For self-signed dev, we use client_unsafe and pass the known dev cert
	var cert = X509Certificate.new()
	cert.load(CERT_PATH)
	return TLSOptions.client_unsafe(cert)
