module analyzer

import ast
import tree_sitter_v as v
import tree_sitter

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

fn (mut store ProjectStore) generate_module_id() ModuleId {
	defer { store.module_id_counter++ }
	return store.module_id_counter
}

fn (mut store ProjectStore) generate_file_id() FileId {
	defer { store.file_id_counter++ }
	return store.file_id_counter
}

pub fn (mut store ProjectStore) add_file(file_path string, tree ast.Tree, src_text tree_sitter.SourceText) FileLocation {
	dir := os.dir(file_path)
	mut proj := store.project_by_dir(dir) or {
		store.project_paths << dir
		new_project := &Project{
			path: dir
		}
		store.projects << new_project
		new_project
	}

	mut module_name := 'main'
	// scan for module_declaration
	// TODO: use queries
	if module_node := tree.root_node().node_by_type(v.NodeType.module_clause) {
		module_name = module_node.named_child(module_node.named_child_count() - 1).text(src_text)
	}

	defer { store.file_id_counter++ }
	return proj.add_file(
		store.generate_file_id, 
		store.generate_module_id, 
		module_name, 
		file_path
	)
}

pub fn (mut store ProjectStore) delete_file(location FileLocation) ? {

}

pub fn (store &ProjectStore) has_project(dir string) bool {
	return store.project_paths.index(dir) != -1
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
	module_names []string  = []string{cap: 255}
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

pub fn (mut proj Project) add_file(file_id fn () FileId, module_id fn () ModuleId, module string, file_path string) FileLocation {
	mut mod := proj.modules.find_by_name(module_name) or {
		proj.new_module(module_id(), module_name, dir)
	}

	mod.files << infer_file_by_file_path(file_id(), file_path)
	return FileLocation{
		module_id: mod.id
		file_id: new_file.id
	}
}

pub type ModuleId = u16
pub type FileId = u16

[heap]
pub struct Module {
pub:
	id              ModuleId [required]
pub mut:
	sym_id_counter  u16 = 1
	name            string [required]
	path            string [required]
	symbols         []&Symbol = []&Symbol{cap: 500}
	files           []&File = []&File{cap: 255}
}

pub fn (mods []Module) find_by_name(id name) ?&Module {
	for mod in mods {
		if mod.name == name {
			return mod
		}
	}
	return none
}

pub fn (mods []Module) index_by_id(id ModuleId) ?int {
	for i, mod in mods {
		if mod.id == id {
			return i
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
	} else if name.ends_with('.js') {
		language = .js
	} else if name.ends_with('.native') {
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

	return &File{
		path: path
		id: id
		language: language
		platform: platform
		for_define: for_define
		for_ndefine: for_ndefine
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
	symbol_locs []SymbolLocation = []SymbolLocation{cap: 300}
}

pub struct FileLocation {
	module_id ModuleId
	file_id   FileId
}

pub fn (a FileLocation) ==(b FileLocation) bool {
	return a.module_id == b.module_id && a.file_id == b.file_id
}