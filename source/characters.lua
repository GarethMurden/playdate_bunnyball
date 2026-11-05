local pd <const> = playdate
local gfx <const> = pd.graphics

ANIMALS = {
	'bunny',
	'hamster',
	'bird',
	'rat',
	'cat',
	'ferret',
	'snake',
	'bugs',
	'tortoise'
}

CHARACTERS = {
	bunny = { 			-- nb
		animal = 'bunny',
		name = 'Fluff',
		intro = {'A Jack of all trades', 'but master of none'},
		speed = 3,
		strength = 3,
		health = 3,
		hitbox = {8, 35},
		carry_position = {8, 10},
		assets = {
			icon = gfx.image.new('assets/animals/bunny_icon'),
			idle_cpu = gfx.image.new('assets/animals/bunnyCPU_idle'),
			idle_player = gfx.image.new('assets/animals/bunny_idle'),
			hit_player = gfx.image.new('assets/animals/bunny_hit'),
			hit_cpu = gfx.image.new('assets/animals/bunnyCPU_hit'),
			run_sequence = {
				gfx.image.new('assets/animals/bunny_run_01.png'),
				gfx.image.new('assets/animals/bunny_run_01.png'),
				gfx.image.new('assets/animals/bunny_run_01.png'),
				gfx.image.new('assets/animals/bunny_run_02.png'),
				gfx.image.new('assets/animals/bunny_run_02.png'),
				gfx.image.new('assets/animals/bunny_run_02.png'),
				gfx.image.new('assets/animals/bunny_run_03.png'),
				gfx.image.new('assets/animals/bunny_run_03.png'),
				gfx.image.new('assets/animals/bunny_run_03.png'),
				gfx.image.new('assets/animals/bunny_run_04.png'),
				gfx.image.new('assets/animals/bunny_run_04.png'),
				gfx.image.new('assets/animals/bunny_run_04.png')
			}
		}
	},
	hamster = { 		-- nb
		animal = 'hamster',
		name = 'Cheeks',
		intro = {'Much tougher than', 'they look'},
		speed = 3,
		strength = 3,
		health = 4,
		hitbox = {8, 35},
		carry_position = {5, 20},
		assets = {
			icon = gfx.image.new('assets/animals/hamster_icon'),
			idle_cpu = gfx.image.new('assets/animals/hamsterCPU_idle'),
			idle_player = gfx.image.new('assets/animals/hamster_idle'),
			hit_player = gfx.image.new('assets/animals/hamster_hit'),
			hit_cpu = gfx.image.new('assets/animals/hamsterCPU_hit'),
			run_sequence = {
				gfx.image.new('assets/animals/hamster_run_01.png'),
				gfx.image.new('assets/animals/hamster_run_01.png'),
				gfx.image.new('assets/animals/hamster_run_02.png'),
				gfx.image.new('assets/animals/hamster_run_02.png'),
				gfx.image.new('assets/animals/hamster_run_03.png'),
				gfx.image.new('assets/animals/hamster_run_03.png'),
				gfx.image.new('assets/animals/hamster_run_04.png'),
				gfx.image.new('assets/animals/hamster_run_04.png')
			}
		}
	},
	bird = {			-- m
		animal = 'bird',
		name = 'Johnathon',
		intro = {'Look at him fly!', 'So fast!'},
		speed = 4,
		strength = 3,
		health = 3,
		hitbox = {8, 35},
		carry_position = {5, 25},
		assets = {
			icon = gfx.image.new('assets/animals/bird_icon'),
			idle_cpu = gfx.image.new('assets/animals/birdCPU_idle'),
			idle_player = gfx.image.new('assets/animals/bird_idle'),
			hit_player = gfx.image.new('assets/animals/bird_hit'),
			hit_cpu = gfx.image.new('assets/animals/birdCPU_hit'),
			run_sequence = {
				gfx.image.new('assets/animals/bird_run_01.png'),
				gfx.image.new('assets/animals/bird_run_01.png'),
				gfx.image.new('assets/animals/bird_run_02.png'),
				gfx.image.new('assets/animals/bird_run_02.png'),
				gfx.image.new('assets/animals/bird_run_03.png'),
				gfx.image.new('assets/animals/bird_run_03.png'),
				gfx.image.new('assets/animals/bird_run_04.png'),
				gfx.image.new('assets/animals/bird_run_04.png')
			}
		}
	},
	rat = {				-- f
		animal = 'rat',
		name = 'Pricilla',
		intro = {'This one throws hard!', ''},
		speed = 3,
		strength = 4,
		health = 3,
		hitbox = {8, 45},
		carry_position = {8, 20},
		assets = {
			icon = gfx.image.new('assets/animals/rat_icon'),
			idle_cpu = gfx.image.new('assets/animals/ratCPU_idle'),
			idle_player = gfx.image.new('assets/animals/rat_idle'),
			hit_player = gfx.image.new('assets/animals/rat_hit'),
			hit_cpu = gfx.image.new('assets/animals/ratCPU_hit'),
			run_sequence = {
				gfx.image.new('assets/animals/rat_run_01.png'),
				gfx.image.new('assets/animals/rat_run_01.png'),
				gfx.image.new('assets/animals/rat_run_02.png'),
				gfx.image.new('assets/animals/rat_run_02.png'),
				gfx.image.new('assets/animals/rat_run_03.png'),
				gfx.image.new('assets/animals/rat_run_03.png'),
				gfx.image.new('assets/animals/rat_run_04.png'),
				gfx.image.new('assets/animals/rat_run_04.png')
			}
		}
	},
	cat = {				-- m
		animal = 'cat',
		name = 'Caspian',
		intro = {'Having nine lives seems', 'a little unfair'},
		speed = 4,
		strength = 4,
		health = 6,
		hitbox = {8, 35},
		carry_position = {10, 15},
		assets = {
			icon = gfx.image.new('assets/animals/cat_icon'),
			idle_cpu = gfx.image.new('assets/animals/catCPU_idle'),
			idle_player = gfx.image.new('assets/animals/cat_idle'),
			hit_player = gfx.image.new('assets/animals/cat_hit'),
			hit_cpu = gfx.image.new('assets/animals/catCPU_hit'),
			run_sequence = {
				gfx.image.new('assets/animals/cat_run_01.png'),
				gfx.image.new('assets/animals/cat_run_01.png'),
				gfx.image.new('assets/animals/cat_run_02.png'),
				gfx.image.new('assets/animals/cat_run_02.png'),
				gfx.image.new('assets/animals/cat_run_03.png'),
				gfx.image.new('assets/animals/cat_run_03.png'),
				gfx.image.new('assets/animals/cat_run_04.png'),
				gfx.image.new('assets/animals/cat_run_04.png')
			}
		}
	},
	ferret = {			-- f
		animal = 'ferret',
		name = 'Ottoline',
		intro = {'Ferrets are just', 'long cats, right?'},
		speed = 6,
		strength = 4,
		health = 4,
		hitbox = {10, 18},
		carry_position = {5, 10},
		assets = {
			icon = gfx.image.new('assets/animals/ferret_icon'),
			idle_cpu = gfx.image.new('assets/animals/ferretCPU_idle'),
			idle_player = gfx.image.new('assets/animals/ferret_idle'),
			hit_player = gfx.image.new('assets/animals/ferret_hit'),
			hit_cpu = gfx.image.new('assets/animals/ferretCPU_hit'),
			run_sequence = {
				gfx.image.new('assets/animals/ferret_run_01.png'),
				gfx.image.new('assets/animals/ferret_run_01.png'),
				gfx.image.new('assets/animals/ferret_run_02.png'),
				gfx.image.new('assets/animals/ferret_run_02.png'),
				gfx.image.new('assets/animals/ferret_run_03.png'),
				gfx.image.new('assets/animals/ferret_run_03.png'),
				gfx.image.new('assets/animals/ferret_run_04.png'),
				gfx.image.new('assets/animals/ferret_run_04.png')
			}
		}
	},
	snake = {			-- nb
		animal = 'snake',
		name = 'Noodle',
		intro = {'No arms?', 'No problem'},
		speed = 4,
		strength = 6,
		health = 4,
		hitbox = {8, 35}, 
		carry_position = {-10, 13},
		assets = {
			icon = gfx.image.new('assets/animals/snake_icon'),
			idle_cpu = gfx.image.new('assets/animals/snakeCPU_idle'),
			idle_player = gfx.image.new('assets/animals/snake_idle'),
			hit_player = gfx.image.new('assets/animals/snake_hit'),
			hit_cpu = gfx.image.new('assets/animals/snakeCPU_hit'),
			run_sequence = {
				gfx.image.new('assets/animals/snake_run_01.png'),
				gfx.image.new('assets/animals/snake_run_01.png'),
				gfx.image.new('assets/animals/snake_run_02.png'),
				gfx.image.new('assets/animals/snake_run_02.png'),
				gfx.image.new('assets/animals/snake_run_03.png'),
				gfx.image.new('assets/animals/snake_run_03.png'),
				gfx.image.new('assets/animals/snake_run_04.png'),
				gfx.image.new('assets/animals/snake_run_04.png')
			}
		}
	},
	bugs = {		-- nb
		animal = 'bugs',
		name = 'The Swarm',
		intro = {'All for one', 'and one for all'},
		speed = 6,
		strength = 4,
		health = 6,
		hitbox = {8, 35},
		carry_position = {0, 10},
		assets = {
			icon = gfx.image.new('assets/animals/bugs_icon'),
			idle_cpu = gfx.image.new('assets/animals/bugsCPU_idle'),
			idle_player = gfx.image.new('assets/animals/bugs_idle'),
			hit_player = gfx.image.new('assets/animals/bugs_hit'),
			hit_cpu = gfx.image.new('assets/animals/bugsCPU_hit'),
			run_sequence = {
				gfx.image.new('assets/animals/bugs_run_01.png'),
				gfx.image.new('assets/animals/bugs_run_01.png'),
				gfx.image.new('assets/animals/bugs_run_02.png'),
				gfx.image.new('assets/animals/bugs_run_02.png'),
				gfx.image.new('assets/animals/bugs_run_03.png'),
				gfx.image.new('assets/animals/bugs_run_03.png'),
				gfx.image.new('assets/animals/bugs_run_04.png'),
				gfx.image.new('assets/animals/bugs_run_04.png')
			}
		}
	},
	tortoise = {		-- nb
		animal = 'tortoise',
		name = 'Plod',
		intro = {'One tough customer', ''},
		speed = 4,
		strength = 6,
		health = 6,
		hitbox = {8, 15},
		carry_position = {20, 10},
		assets = {
			icon = gfx.image.new('assets/animals/tortoise_icon'),
			idle_cpu = gfx.image.new('assets/animals/tortoiseCPU_idle'),
			idle_player = gfx.image.new('assets/animals/tortoise_idle'),
			hit_player = gfx.image.new('assets/animals/tortoise_hit'),
			hit_cpu = gfx.image.new('assets/animals/tortoiseCPU_hit'),
			run_sequence = {
				gfx.image.new('assets/animals/tortoise_run_01.png'),
				gfx.image.new('assets/animals/tortoise_run_01.png'),
				gfx.image.new('assets/animals/tortoise_run_02.png'),
				gfx.image.new('assets/animals/tortoise_run_02.png'),
				gfx.image.new('assets/animals/tortoise_run_03.png'),
				gfx.image.new('assets/animals/tortoise_run_03.png'),
				gfx.image.new('assets/animals/tortoise_run_04.png'),
				gfx.image.new('assets/animals/tortoise_run_04.png')
			},
			player_run_sequence = {
				gfx.image.new('assets/animals/tortoise_run_01.png'),
				gfx.image.new('assets/animals/tortoise_run_01.png'),
				gfx.image.new('assets/animals/tortoise_run_02.png'),
				gfx.image.new('assets/animals/tortoise_run_02.png'),
				gfx.image.new('assets/animals/tortoise_run_03.png'),
				gfx.image.new('assets/animals/tortoise_run_03.png'),
				gfx.image.new('assets/animals/tortoise_run_04.png'),
				gfx.image.new('assets/animals/tortoise_run_04.png')
			}
		}
	},
	unknown = {
		assets = {
			icon = gfx.image.new('assets/padlock_small'),
			idle_cpu = gfx.image.new('assets/animals/unknown')
		},
		speed = 0,
		strength = 0,
		health = 0
	}
}