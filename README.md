# Synopsis

This repository is an Elixir learning exercise.

**Disclaimer : Do not use this code in production.**

## Subject of the exercise

The subject of this exercise is to play with `Cowboy`, `Plug` and `CryptoBlocks`

Send files to the webserver and store them encrypted in many blocks.

## Setup

Clone the repository, then :

```sh
mix deps.get
```

Configure the settings :

```sh
cd config
cp SAMPLE.settings.json settings.json
```

Edit the `settings.json` file to suit you need, ie :

```json
{ 
  "read_size": 1048576,
  "block_size": 524288,
  "blocks_path": "/..absolut-path-to../storage/blocks",
  "files_path": "/..absolut-path-to../storage/files"
}
```

## Sending file to the server

Generate random binary file (or take any binary file you want):

```sh
mkdir ./tmp
dd if=/dev/random of=./tmp/file-9mb.bin bs=1 count=9545925
```

Send file to the server :

```sh
curl -X POST localhost:4554 --data-binary @tmp/file-9mb.bin
```

You should receive a JSON reponse with the `id` of the stored file, ex :

```
{"id","e425c0d8983da48cecc5a0eb04620671"}
```

## Download file from server

```sh
curl -OJ -X GET localhost:4554/id/e425c0d8983da48cecc5a0eb04620671
```

# Roadmap

- [X] Simple Router (with "/")
- [X] Add simple config system (basic KV genserver)
- [X] Basic endpoint to send file
- [X] Endpoint to download file
- [X] Compute optimal block size based on content-length
- [ ] Encrypt the blocks description
- [ ] Setup for master key
- [ ] Filename management
- [ ] Error handling
