
~get_residu = {|perf, tempi, score, verbose=true|

	var initial_tempo = score[0] / perf[0];
	var result, scoreTmp = score.integrate;
	scoreTmp.removeAt(0);

	if(verbose)
	{
		"SCORE\t IOI\t TEMPO\t DELTA\t RESIDU\t TTRACKER".postln;
	};
	scoreTmp.size.do{|i|
		var ioi = perf[i];
		var tempo = tempi[i];
		var s = score[i];
		var score_pos, nominal_perf, perf_tempo, delta_tempo, residu, new_tempo;
		score_pos = scoreTmp[i];
		nominal_perf = s / initial_tempo;
		perf_tempo = initial_tempo / (s / ioi);
		delta_tempo = perf_tempo - tempo;
		residu = nominal_perf * (1 + delta_tempo);
		new_tempo = perf_tempo - delta_tempo;

		if(verbose)
		{
			"%\t %\t %\t %\t %\t %\t".format(score_pos, ioi, perf_tempo, delta_tempo, residu, new_tempo).postln;
		};
		result = result.add(residu);
	};
	result
};

~get_residu.([0.5990422978731538, 0.7972410051791009, 1.666666666666667], [1, 1, 1.1], [2, 2, 2]);

~generate_table_all_models_new = {|
	score,
	w = 0.3,
	q = 2,
	factor = 0.25,
	perf,
	lk_init_period,
	lk_init_phase = 0,
	lk_period_strenght = 0.4,
	lk_phase_strength = 1,
	lk_gamma = 3,
	trad_speed = 1,
	trad_trust = 1,
	verbos = true,
	table = true|




};

//constant variables - yack
~period;
~phi;
~expected;


//
~init_large_kolen = {|init_period = 0.5, init_phase = 0|
	~period = init_period;
	~phi = init_phase;
	~expected = 0;
};

// "Large & Kolen adaptative oscillator; from Rowe, 2003, p. 139 / Toiviainen, 1998, p. 64"
// this is basically a sin osc

~large_kolen = {|pulse, time, period_strength = 1, phase_strength = 1, gamma = 1, verbose=false|
	var adapt, phi, period, expected;
	period = ~period; //note this is bad style - just copying the lisp stuff here
	expected = ~expected;
	period = ~period;
	if((expected + (period /2)) < time)
	{
		expected = expected + period;
	};
	phi = (time - expected) / period; //Eq. 2
	if(pulse)
	{
		adapt = gamma * (cos(1 - (2 * pi * phi))); //pi is a sc constant
		adapt = 1 / cosh(adapt); //sech
		adapt = adapt * adapt; //power two
		adapt = adapt * (sin(2 * pi * phi));

		//update expected-time (tx) and phase (phi)
		period = period + (adapt * period_strength);
		expected = expected + (adapt * phase_strength);
		phi = (time - expected) / period; //updated phase
		if(verbose)
		{
			//print some stuff
		};
	};

	~period = period;
	~expected = expected;
	~period = period;

	//output osc values
	//return a list
	[1 + (tanh(gamma * (1- cos(2 * pi * phi)))), period, phi, expected];
};

//  "Normalized function from Friberg & Sundberg(1999); v(x)=[1+(w^q-1)x]1/q"

~physical_motion_ritard = {|x, w=0.3, q=1|
	(1 + (((w ** q) -1) * x) **  (1/q));
};

~apply_triad_fun = {|score, w=0.3, q=1, f= 0.25| //tempo 1 at onset second note/endtempo ok
	var length;
	var pos = 0;
	var result;

	length = score.sum;
	score.do{|s_ioi|
		var x, tempo_factor, p_ioi;
		x = (pos / (length - score.last()));
		tempo_factor = ~physical_motion_ritard.(x, w: w, q: q);
		p_ioi = (f * (s_ioi / tempo_factor));

		// "% % %".format(x, tempo_factor, p_ioi).postln;
		result = result.add(p_ioi);
		pos = pos + s_ioi;


	};
	result;
};

~large_kolen_tempo_tracker = {|perf, init_period = 0.5, init_phase=0, period_strength=1, phase_strength=1, gamma = 3,verbose = false, resolution = 0.1|
	var onsets, next, end, dotimes, time, adaptiveOscRet, returnArray, period, value, phase, tx;
	~init_large_kolen.(init_period, init_phase);
	period = ~period; // bad style with global variables again ...
	onsets = perf.integrate;
	next = onsets[0];
	onsets.removeAt(0);
	end = onsets.last() + 1;

	dotimes = end / resolution;
	time = 0;
	block{|break|

	dotimes.do{|i|
		var pulse;
		pulse = (time > next);
		if(pulse)
		{
			if(onsets.size == 0)
			{
					break.(returnArray);
			};
			next = onsets.removeAt(0); // aka lisp (pop ..)
		};
		adaptiveOscRet = ~large_kolen.(pulse, time, period_strength:period_strength, phase_strength: phase_strength, gamma:gamma, verbose:verbose);
		if(verbose)
		{
			//print some stuff
		};

		returnArray = returnArray.add([time, period]); //in lisp there's some rounding for time
		value = adaptiveOscRet[0];
		period = adaptiveOscRet[1];
		phase = adaptiveOscRet[2];
		tx = adaptiveOscRet[3];

		time = time + resolution;

	};

	};
	~period = period;
	returnArray
};

//

//tests

~physical_motion_ritard.(0.5); //ok
~apply_triad_fun.([4, 4, 4], 0.9, 1, 0.25); //ok
~large_kolen_tempo_tracker.(~apply_triad_fun.([2, 2, 2, 2, 2, 2, 2, 2, 2, 2], w: 0.6, q:2, f: 0.25));

/*
;;; ************************************************************************
;;; ************************************************************************
;;; MICRO TRADITIONAL QUANTIZER
;;; (C)1990, Desain & Honing
;;; in Common Lisp (uses loop macro)

;;; utilities
*/

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
	1 - ((1- trust) * (~square.(2 *error)));
};

/*
  "Quantize time intervals in multiples of quantum"
  ;; speed = 0, trust = 1 :inter-onset quantizer
  ;; 0<speed<1, trust = 1 :tempo tracker
  ;; 0<speed<1, 0<trust<1 :tempo tracker with confidenc
*/

~traditional_quantize = {|intervals, speed=0.9, trust=0.9, quantum=0.05|
	var out, error;
	intervals.collect{|in|
		out = ~quantize_ioi.(in, quantum);
		error = ~quantization_error.(in, out, quantum);
		quantum = quantum + (~delta_quantum.(error, out, quantum) * ~confidence.(error, trust) * speed);
		quantum.postln;
		out
	};
};

//  "a la dannenberg & mont-reynaud, 19??; NB knowing the score"
/*
  ;; speed = 0, trust = 1 :inter-onset quantizer
  ;; 0<speed<1, trust = 1 :tempo tracker
  ;; 0<speed<1, 0<trust<1 :tempo tracker with confidence
*/

~traditional_tempo_tracker = {|intervals, speed = 1, trust = 0.8, quantum = 1, verbose = true|
	var result, f, tracked, one_over;
	result = ~traditional_quantize.(intervals, speed, trust, quantum);
	f = result[0] / intervals[0];
	intervals.do{|p, i|
		var val, q;
		q = result[i];
		val = (q / p / f);
		tracked  =tracked.add(val);
	};
	if(verbose)
	{
		"input: % \n quant: % \n output: % \n f: %".format(intervals, result, tracked, f).postln;
	};
	tracked;
};

~traditional_quantize.([1.034, 1.071, 1.111], quantum: 0.05);

~traditional_quantize.([0.500, 0.516, 0.533, 0.552, 0.574, 0.598], quantum: 0.05);
~traditional_tempo_tracker.([0.500, 0.516, 0.533, 0.552, 0.574, 0.598], quantum: 0.05);

~mean = {|...args|
	args.sum / args.size;
};

//note: quantum is not being passed in to quantization_model in this function! (in lisp &rest args)

~search_borders = {|... args|
	var quantization_model, pre_iois, ioi, score;
	var min, initial, s_factor, new_score;
	var downTo, downToDoTimes, stepSize = 0.01;
	var result;

	//argument mapping
	quantization_model = args.removeAt(0);
	pre_iois = args.removeAt(0);
	ioi = args.removeAt(0);
	score = args.removeAt(0);

	min = 0.05;
	initial = [pre_iois, ioi, args].flat;
	// initial.postln;

	//apply model
	initial = quantization_model.(initial);


	s_factor = initial[0] / score[0];

	new_score = score.collect{|it|
		it * s_factor;
	};

	// [new_score, initial].postln; //debugging

	downTo = ioi / 10.0;//max( min(ioi / 10.0)); // why min max this ?
	//could do this with a while loop too ...
	downToDoTimes = (ioi - downTo) / stepSize;

	block{|break|
		var interval = ioi;
		downToDoTimes.do{|i|
			var new, quant;
			new = quantization_model.([pre_iois, interval].flat);
			quant = new.last();
			if(quant <= (new_score.last() * (3 / 4)))
			{
				result = result.add(interval);
				break.();
			};
			interval = interval - stepSize;
		};
	};

	{
		var factor = score.first() / pre_iois.first(); //(pre_iois.first() or: ioi);
		var new = quantization_model.([pre_iois, ioi].flat);
		var quant = new.last(); // current quant
		result = result.add(factor / quant);
	}.value;

	block{|break|
		var interval = ioi;
		downToDoTimes = ((ioi + 10) - ioi) / stepSize;
		downToDoTimes.do{|i|
			var new, quant;
			new = quantization_model.([pre_iois, interval].flat);
			quant = new.last();
			if(quant >= (new_score.last() * (4 / 3)))
			{
				result = result.add(interval);
				break.();
			};
			interval = interval + stepSize;
		};
	};

	result;
};


~search_borders.(~traditional_quantize, [0.5, 0.5], 0.5, [2, 2, 2]);

~apply_ritard_fun = {|score, w=0.3, q=1, f=0.25|
	var length = score.sum();
	var pos = 0;
	score.collect{|s_ioi|
		var x = (pos / (length - score.last()));
		var tempo_factor = ~physical_motion_ritard.(x, w, q);
		var p_ioi = (f * (s_ioi / tempo_factor));
		pos = pos + s_ioi;
		p_ioi; //value to collect
	};
};

~apply_ritard_fun.([4, 4, 4], 0.9, 1, 0.25);

~perf_round = {|ioi|
	(ioi * 1000).round / 1000.0;
};

~perf_round.(0.324324);

//putting it all together

~generate_table_all_models_new  = {|score, w=0.3, q=2, factor=0.25, perf, lk_init_period, lk_init_phase = 0, lk_period_strength = 0.4, lk_phase_strength = 1, lk_gamma = 3, trad_speed = 1, trad_trust = 1, verbose=true, table=true|
	var result, result_lp, trad_tempi, tempi, tempi_lp, residu;

	perf = ~apply_ritard_fun.(score, w, q, f);
	lk_init_period = perf.first();

	//track tempo of performance
	result = ~large_kolen_tempo_tracker.(perf, lk_init_period, lk_init_phase, lk_period_strength, lk_phase_strength, lk_gamma, resolution: 0.001);

	//track tempo of performance
	//period coupling-strength, Large & Palmer, 2002
	result_lp = ~large_kolen_tempo_tracker.(perf, lk_init_period, lk_init_phase, 4, 1, 1, resolution: 0.001);

	trad_tempi = ~traditional_tempo_tracker.(perf, speed: trad_speed, trust: trad_trust, quantum: 0.05, verbose:verbose);

	//collect tempi at onsets from L&K
	{
		var perf_onsets_cp = perf_onsets.deepCopy();
		var perf_onsets = perf.integrate();
		var time;
		perf_onsets.removeAt(0); //rest
		time = perf_onsets_cp.removeAt(0); //pop
		result.do{|arr|
			var perf_time = arr[0];
			var period = arr[1];
			if(perf_time == ~perf_round.(time))
			{
				tempi = tempi.add(period / perf[0]);
			};
			time = perf_onsets_cp.removeAt(0); //pop
		};

	}.value;

	//collect tempi at onsets from L&K
	{
		var perf_onsets_cp = perf_onsets.deepCopy();
		var perf_onsets = perf.integrate();
		var time;
		perf_onsets.removeAt(0); //rest
		time = perf_onsets_cp.removeAt(0); //pop
		result_lp.do{|arr|
			var perf_time = arr[0];
			var period = arr[1];
			if(perf_time == ~perf_round.(time))
			{
				tempi = tempi.add(period / perf[0]);
			};
			time = perf_onsets_cp.removeAt(0); //pop
		};

	}.value;

	residu = ~get_residu.(perf, tempi, score, verbose);

	//b e sure the're euqal length
	// really? - how will a print line ensure that - jt ;)
	[perf.size, score.size, tempi.size].println;

	//here is happening something with the quantizers but they seem not tobe used elsewhere ...
	{
		var lh, con, tt;

	};


};
