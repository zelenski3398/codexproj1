class_name AAFireControl
extends RefCounted
## Solve the low-time intercept with constant target velocity and shell gravity.
## No damage or explosions are generated here: the gun must launch a real shell.
static func solve(origin: Vector3, target: Vector3, velocity: Vector3, speed: float, gravity: float, lifetime: float) -> Dictionary:
	if speed<=0 or lifetime<=0:return {}
	var previous: float=.001
	var previous_value: float=_error(previous,origin,target,velocity,speed,gravity)
	var time: float=previous
	var valid:=false
	for i in range(1,161):
		time=lifetime*i/160.0
		var value: float=_error(time,origin,target,velocity,speed,gravity)
		if value<=0 and previous_value>=0:
			var low:=previous
			var high:=time
			for iteration in range(22):
				var mid: float=(low+high)*.5
				if _error(mid,origin,target,velocity,speed,gravity)>0:low=mid
				else:high=mid
			time=(low+high)*.5
			valid=true
			break
		previous=time
		previous_value=value
	if not valid:time=clampf(origin.distance_to(target)/speed,.05,lifetime)
	var intercept: Vector3=target+velocity*time
	var direction: Vector3=(intercept-origin+Vector3.UP*.5*gravity*time*time).normalized()
	return {"valid":valid,"time":time,"point":intercept,"direction":direction}

static func _error(t: float,origin: Vector3,target: Vector3,velocity: Vector3,speed: float,gravity: float) -> float:
	return (target+velocity*t-origin+Vector3.UP*.5*gravity*t*t).length_squared()-speed*speed*t*t
