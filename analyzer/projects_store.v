module analyzer

/*
In V terminology, a "module" is defined as a collection of files in a directory.
However, there are some instances that a directory may mixed "main" and non-"main" files.

In order to fix this confusion, the word "project" is used in VLS as having a
directory which comprises of multiple modules. This also includes subdirectories
named as "submodules".

In a sense, a project may contain multiple modules and modules may contain multiple files.

How about submodules from 2nd-to-n levels? They are still stored in the same project
since Project.module is just a flat list. An identifier is also linked so it does not
have any conflicts with module names that have similar names.
*/

pub struct ProjectStore {
mut:
	module_id_counter  u16 = 1
	file_id_counter    u16 = 1
	project_paths      []string = []string{cap: 65535}
pub mut:
	projects           []&Project = []&Project{cap: 65535}
}

pub fn (mut store ProjectStore) add_file(file_path string, tree C.TSTree) FileLocation {
	dir := os.dir(file_path)
	mut proj := store.project_by_dir(dir) or {
		store.project_paths << dir
		new_project := &Project{
			path: dir
		}
		store.projects << new_project
		new_project
	}

	// scan for module_declaration
	// TODO: use queries
	mut nodes := new_tree_cursor(tree.root_node())
	mut module_name := 'main'

	for node in nodes {
		if node.type_name() == 'module_clause' {
			module_name = node.named_child(node.named_child_count() - 1)
			break
		}
	}

	mut mod := proj.modules.find_by_name(module_name) or {
		new_proj := proj.new_module(store.module_id_counter, module_name, dir)
		store.module_id_counter++
		new_proj
	}

	new_file := infer_file_by_file_path(store.file_id_counter, file_path)
	store.file_id_counter++

	mod.files << new_file
	return FileLocation{
		module_id: mod.id
		file_id: new_file.id
	}
}

pub fn (store &ProjectStore) project_by_dir(dir string) ?&Project {
	idx := store.project_paths.index(dir)
	if idx == -1 {
		return none
	}
	return store.projects[idx]
}

[heap]
pub struct Project {
pub mut:
	path         string [required]
	module_names []string = []string{cap: 255}
	modules      []&Module = []Module{cap: 255}
}

pub fn (mut proj Project) new_module(id ModuleId, name string, path string) &Module {
	proj.module_names << name
	new_mod := &Module{
		id: id
		name: name
		path: path
	}
	proj.modules << new_mod
	return new_mod
}

pub type ModuleId = u16
pub type FileId = u16

[heap]
pub struct Module {
pub mut:
	id    ModuleId [required]
	name  string [required]
	path  string [required]
	files []&File = []&File{cap: 255}
}

pub fn (mods []Module) find_by_name(id name) ?&Module {
	for mod in mods {
		if mod.name == name {
			return mod
		}
	}
	return none
}

fn infer_file_by_file_path(id FileId, path string) &File {
	file_name := os.base(path)
	mut name := file_name.all_before_last('.v')
	mut language := SymbolLanguage.v
	mut platform := Platform.cross
	mut for_define := ''
	mut for_ndefine := ''

	// language
	if name.ends_with('.c') {
		language = .c
	} else name.ends_with('.js') {
		language = .js
	} else name.ends_with('.native') {
		language = .native
	}

	if language != .v {
		len := match language {
			.v, .c { 1 }
			.js { 2 }
			.native { 6 }
		}
		name = name[.. 1 + len]

		// platform
		if platform_sep_idx := name.last_index_u8('_') {
			platform = match name[platform_sep_idx ..] {
				'ios' { Platform.ios }
				'macos' { Platform.macos }
				'linux' { Platform.linux }
				'windows' { Platform.windows }
				'freebsd' { Platform.freebsd }
				'openbsd' { Platform.openbsd }
				'netbsd' { Platform.netbsd }
				'dragonfly' { Platform.dragonfly }
				'android' { Platform.android }
				'solaris' { Platform.solaris }
				'haiku' { Platform.haiku }
				'serenity' { Platform.serenity }
				else { Platform.cross }
			}
		}
	} else if '_d_' in name {
		// defines
		for_define = name.all_after_last('_d_')
	} else if '_notd_' in name {
		for_ndefine = name.all_after_last('_notd_')
	}

	return &File {
		path: path
		id: id
		language: language
		platform: platform
		for_define: for_define
		for_nddefine: for_ndefine
	}
}

pub enum FileLanguage {
	v
	c
	js
	native
}

pub enum Platform {
	ios
	macos
	linux
	windows
	freebsd
	openbsd
	netbsd
	dragonfly
	android
	solaris
	haiku
	serenity
	cross
}

[heap]
pub struct File {
pub mut:
	path        string [required]
	id          FileId [required]
	language    FileLanguage = .v
	platform    Platform     = .cross
	for_define  string
	for_ndefine string
	scopes      []&ScopeTree // TODO: remove later
	symbols     []&Symbol = []&Symbol{cap: 255}
}

pub struct FileLocation {
	module_id ModuleId
	file_id   FileId
}
