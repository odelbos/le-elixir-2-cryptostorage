# Synopsis

This repository is an Elixir learning exercise.

**Disclaimer : Do not use this code in production.**

## Subject of the exercise

The subject of this exercise is to play with `Cowboy`, `Plug` and `CryptoBlocks`

Send files to the web server and store them encrypted in many blocks. For this purpose we will used the preceding learning exercise [CryptoBlocks](https://github.com/odelbos/le-elixir-1-cryptoblocks).

Features :

* Use an AES 256 key to encrypt the blocks description,
* The AES key is not stored on the web server, it must be send after the server startup by calling `/setup`,
* Calling `/setup` will work only one time, once the setup is done, calling `/setup` will return a 403 status code (Forbidden),
* If the RSA or AES keys are not set the server will respond with a 503 status code (Service Unavailable).

## Setup

Clone the repository, then :

```sh
mix deps.get
```

### Configure the settings

```sh
cd config
cp SAMPLE.settings.json settings.json
chmod 600 settings.json
```

Edit the `settings.json` file to suit you need, ie :

```json
{ 
  "blocks_path": "/..absolut-path-to../blocks",
  "files_path": "/..absolut-path-to../files",
  "pub_key": "..rsa-pub-key.."
}
```

### Generate RSA keys and AES key.

We use the `crypto_storage_cli` project to generate the RSA and AES keys.  
Also the CLI is used to send the AES storage key to the web server.

See the following [StorageManager](http://wait.com) repository for more details.

```sh
./storage_mnager add --name <server_name> --url http://localhost:4554/setup
```

Get the RSA public key and paste it into the settings.json.

### Start the server

```sh
mix run --no-halt
```

### Send the AES 256 key to the server

Use the `storage_manager` to send the AES storage key to the server.  
This will finish the setup of the server.

```sh
./storage_manager setup --name <server_name>
```

_(Each time the server is started, it is necessary to send the storage key.)_

## Sending file to the server

Generate random a binary file (or take any binary file you want):

```sh
mkdir ./tmp
dd if=/dev/random of=./tmp/file-9mb.bin bs=1 count=9545925
```

Send file to the server :

```sh
curl -X POST localhost:4554/store --data-binary @./tmp/file-9mb.bin
```

You should receive a JSON reponse with the `id` of the stored file, ex :

```
{"id","e425c0d8983da48cecc5a0eb04620671"}
```

## Download file from server

```sh
curl -OJ -X GET localhost:4554/get/e425c0d8983da48cecc5a0eb04620671
```

### Compare the checksum

```sh
sha256sum ./tmp/file-9mb.bin
```

```sh
sha256sum ./e425c0d8983da48cecc5a0eb04620671
```



# Roadmap

- [X] Simple Router (with "/")
- [X] Add simple config system (basic KV genserver)
- [X] Basic endpoint to send file
- [X] Endpoint to download file
- [X] Compute optimal block size based on content-length
- [X] Encrypt the blocks description
- [X] Setup for master key
- [ ] Filename management
- [ ] Error handling
