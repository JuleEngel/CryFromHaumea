class_name LicensedCreditEntry
extends RefCounted


var title: String
var authors: Array[String]
var license: String


func _init(
	p_title: String,
	p_authors: Array[String],
	p_license: String
):
	self.title = p_title
	self.authors = p_authors
	self.license = p_license
