~square = {|x| x*x};

~quantize_ioi = {|time, quantum|
	(time / quantum).round;
};


~quantization_error = {|in, out, quantum|
	((in / quantum) - out);
};

~delta_quantum = {|error, out, quantum|
	(quantum * (error / out));
};

~confidence = {|error, trust|
	(1 - (1- trust) * (~square.(2 *error)));
};

~traditional_quantize = {|intervals, speed=0.9, trust=0.9, quantum=1|
	var out, error;
	intervals.collect{|in|
		out = ~quantize_ioi.(in, quantum);
		error = ~quantization_error.(in, out, quantum);
		quantum = quantum + (~delta_quantum.(error, out, quantum) * ~confidence.(error, trust) * speed);
		out
	};
};



~square.(2)


~quantize_ioi.(12.3, 2.4);


~traditional_quantize.([2.05, 1.0, 0.95, 2.0]);

