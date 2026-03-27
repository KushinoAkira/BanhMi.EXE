extends Node

signal money_changed(new_val)
signal day_changed(is_day_now)
signal furniture_purchased(new_count)

var money: int = 100000
var furniture_count: int = 1
var is_day: bool = true
