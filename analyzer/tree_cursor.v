module analyzer

import tree_sitter
import tree_sitter_v as v
import ast

struct TreeCursor {
mut:
	cur_child_idx int  = -1
	named_only    bool = true
	child_count   int                                [required]
	source        tree_sitter.SourceText
	cursor        tree_sitter.TreeCursor<v.NodeType> [required]
}

pub fn (mut tc TreeCursor) next() ?ast.RichNode {
	for tc.cur_child_idx < tc.child_count {
		if tc.cur_child_idx == -1 {
			tc.cursor.to_first_child()
		} else if !tc.cursor.next() {
			return none
		}

		tc.cur_child_idx++
		if cur_node := tc.current_node() {
			if tc.named_only && (cur_node.is_named() && !cur_node.is_extra()) {
				return cur_node
			}
		}
	}

	return none
}

pub fn (mut tc TreeCursor) reset() {
	tc.cursor.to_parent()
	tc.cur_child_idx = -1
}

pub fn (mut tc TreeCursor) to_first_child() bool {
	return tc.cursor.to_first_child()
}

pub fn (tc &TreeCursor) current_node() ?ast.RichNode {
	node := tc.cursor.current_node()?
	return ast.Node(node).with(tc.source)
}

[unsafe]
pub fn (tc &TreeCursor) free() {
	unsafe {
		tc.cursor.raw_cursor.free()
		tc.cur_child_idx = 0
		tc.child_count = 0
	}
}

pub fn new_tree_cursor(root_node ast.RichNode) TreeCursor {
	return TreeCursor{
		source: root_node.src
		child_count: int(root_node.raw_node.child_count())
		cursor: root_node.raw_node.tree_cursor()
	}
}
