class_name GameLicenseCreditEntry
extends RefCounted

var license: String
var year: String
var studio_name: String:
	get():
		return "Ein Spiel von %s" % studio_name

func _init(p_license, p_year, p_studio_name):
	self.license = p_license
	self.year = p_year
	self.studio_name = p_studio_name
	
