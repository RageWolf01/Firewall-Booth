class_name Packet
extends RefCounted

## One "customer" at the booth.
##
## A packet arrives carrying an ID card. The card is what the player reads:
## where it came from, which port it wants, which protocol it speaks, and a
## one-line description of what it is carrying.
##
## `should_allow` is the correct call, and `lesson` is the plain-language reason
## for it. Both are hardcoded per packet for now. When the daily manual becomes
## real data, the reason will be derived from the day's rules instead and these
## fields go away.

## e.g. "192.168.1.45"
var source_ip: String
## e.g. 443
var destination_port: int
## "TCP" or "UDP"
var protocol: String
## Short human description of what the packet carries.
var payload: String
## The correct decision.
var should_allow: bool
## Why that decision is correct, shown to the player after they choose.
var lesson: String


func _init(
	p_source_ip: String,
	p_destination_port: int,
	p_protocol: String,
	p_payload: String,
	p_should_allow: bool,
	p_lesson: String
) -> void:
	source_ip = p_source_ip
	destination_port = p_destination_port
	protocol = p_protocol
	payload = p_payload
	should_allow = p_should_allow
	lesson = p_lesson


## The ID card, as it reads on screen.
func card_lines() -> Array[String]:
	return [
		"Source IP: %s" % source_ip,
		"Destination Port: %d" % destination_port,
		"Protocol: %s" % protocol,
		"Payload: %s" % payload,
	]


## What the correct call was, in one word.
func correct_verdict_word() -> String:
	return "Allow" if should_allow else "Block"
