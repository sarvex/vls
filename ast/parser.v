module ast

import tree_sitter
import tree_sitter_v as v

pub type Node = tree_sitter.Node<v.NodeType>

pub fn (n Node) with(src tree_sitter.SourceText) RichNode {
	return RichNode{n.type_name, n, src}
}

pub type Tree = tree_sitter.Tree<v.NodeType>

pub fn (t &Tree) edit(input_edit &C.TSInputEdit) {
	t.edit(input_edit)
}

pub fn (t &Tree) with(src tree_sitter.SourceText) RichTree {
	return RichTree{unsafe { t }, src}
}

pub fn new_parser() &tree_sitter.Parser<v.NodeType> {
	return tree_sitter.new_parser<v.NodeType>(v.language, v.type_factory)
}

[unsafe]
pub fn unwrap_null_node(err IError) ?Node {
	return Node(unsafe { tree_sitter.unwrap_null_node<v.NodeType>(v.type_factory, err)? })
}

pub fn from_tree(tree &tree_sitter.Tree<v.NodeType>) &Tree {
	return unsafe { tree }
}

[params]
pub struct RichTree {
pub:
	raw_tree &Tree              [required]
	src  tree_sitter.SourceText [required]
}

pub fn (rt RichTree) edit(input_edit &C.TSInputEdit) {
	rt.raw_tree.edit(input_edit)
}

pub fn (rt RichTree) root_node() RichNode {
	return Node(rt.raw_tree.root_node()).with(rt.src)
}

[params]
pub struct RichNode {
pub:
	type_name v.NodeType             [required]
	raw_node  Node                   [required]
	src       tree_sitter.SourceText [required]
}

pub fn (rn RichNode) raw_type_name() string {
	return rn.raw_node.raw_node.type_name()
}

pub fn (rn RichNode) is_null() bool {
	return rn.raw_node.is_null()
}

pub fn (rn RichNode) is_error() bool {
	return rn.raw_node.is_error()
}

pub fn (rn RichNode) is_missing() bool {
	return rn.raw_node.is_missing()
}

pub fn (rn RichNode) is_extra() bool {
	return rn.raw_node.is_extra()
}

pub fn (rn RichNode) is_named() bool {
	return rn.raw_node.is_named()
}

pub fn (rn RichNode) range() C.TSRange {
	return rn.raw_node.range()
}

pub fn (rn RichNode) start_byte() u32 {
	return rn.raw_node.start_byte()
}

pub fn (rn RichNode) end_byte() u32 {
	return rn.raw_node.end_byte()
}

pub fn (rn RichNode) text() string {
	return rn.raw_node.text(rn.src)
}

pub fn (rn RichNode) parent() ?RichNode {
	return Node(rn.raw_node.parent()?).with(rn.src)
}

pub fn (rn RichNode) child_by_field_name(name string) ?RichNode {
	return Node(rn.raw_node.child_by_field_name(name)?).with(rn.src)
}

pub fn (rn RichNode) child(index u32) ?RichNode {
	return Node(rn.raw_node.child(index)?).with(rn.src)
}

pub fn (rn RichNode) named_child(index u32) ?RichNode {
	return Node(rn.raw_node.named_child(index)?).with(rn.src)
}

pub fn (rn RichNode) named_child_count() u32 {
	return rn.raw_node.named_child_count()
}

pub fn (rn RichNode) next_sibling() ?RichNode {
	return Node(rn.raw_node.next_sibling()?).with(rn.src)
}

pub fn (rn RichNode) next_named_sibling() ?RichNode {
	return Node(rn.raw_node.next_named_sibling()?).with(rn.src)
}

pub fn (rn RichNode) prev_sibling() ?RichNode {
	return Node(rn.raw_node.prev_sibling()?).with(rn.src)
}

pub fn (rn RichNode) prev_named_sibling() ?RichNode {
	return Node(rn.raw_node.prev_named_sibling()?).with(rn.src)
}

pub fn (rn RichNode) first_named_child_for_byte(offset u32) ?RichNode {
	return Node(rn.raw_node.first_named_child_for_byte(offset)?).with(rn.src)
}

pub fn (rn RichNode) last_node_by_type(typ v.NodeType) ?RichNode {
	return Node(rn.raw_node.last_node_by_type(typ)?).with(rn.src)
}