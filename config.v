module config

import json
import os
import page_cache

struct Config {
	folders []string [required]
	cached_folders []string
	cached_files []string
}

pub fn load_config(path string) Config {
	config_text := page_cache.read_file(path)

	return json.decode(Config, config_text) or {
		panic('could not parse config! error: $err')
	}
}

pub fn get_all_files(folder_path string) []string {
	shell_command := 'rg --files $folder_path'
	command_result := os.execute_or_exit(shell_command)
	mut files := command_result.output.split('\n')

	for i in 0 .. files.len {
		files[i] = files[i].trim_space()
	}

	return files
}

pub fn apply_config(mut cache page_cache.Cache, cfg Config) {
	folders := cfg.folders
	cached_folders := cfg.cached_folders
	cached_files := cfg.cached_files

	for i in 0 .. cached_folders.len {
		f := cached_folders[i]
		println('cached folder: $f')
	}

	println('applying config...')
	for i in 0 .. folders.len {
		folder := folders[i]
		files := get_all_files(folder)

		for j in 0 .. files.len {
			file := files[j]

			println('file: $file folder: $folder')

			mut should_cache := false

			if folder in cached_folders {
				println('folder was in cached_folders')
				should_cache = true
			}

			if file in cached_files {
				should_cache = true
			}

			if should_cache {
				cache.cache_page(file)
			} else {
				cache.shallow_cache_page(file)
			}
		}
	}
}
