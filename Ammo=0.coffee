# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# Ammo:0 antishooter game v0.04
# Developed in 2019 by V.A. Guevara
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

#.{ [Classes]
class Body
	alive:	true
	ammo:	0
	tempo:	1.5
	thrust: 200
	mengine_off:	20
	dengine_off:	7
	excl_zone:		700
	turbofan:		0
	mass_damping: 	off

	# --Methods goes here.
	constructor: (@sprite_id, @game, x, y, trail_id) ->
		# Init setup.
		@scene		= @game.scene
		@model		= @scene.physics.add.existing @scene.add.container x, y, [@scene.add.image(0, 0, @sprite_id)]
		@requiem	= @scene.sound.add("explode:#{@sprite_id}").on 'complete', (snd) -> snd.destroy()
		@model.self	= @
		@game.objects.push @
		# Trail setup.
		if trail_id?
			engine_template = {blendMode: 'ADD', on: false}
			@engine = 
				main: @game[trail_id].createEmitter Object.assign engine_template,
					speed: {max: 90, min: 100}, scale: { start: 0.02, end: 0 },	
					angle: () => @model.angle + 90 + Phaser.Math.Between -@turbofan, @turbofan
				deltaL: @game[trail_id].createEmitter Object.assign engine_template,
					speed: {max: 250, min: 150}, scale: { start: 0.0225, end: 0 }, lifespan: 300,
					angle: () => @model.angle - 45 + Phaser.Math.Between -@turbofan, @turbofan
				deltaR: @game[trail_id].createEmitter Object.assign engine_template,
					speed: {max: 250, min: 150}, scale: { start: 0.0225, end: 0 }, lifespan: 300,
					angle: () => @model.angle - 135 + Phaser.Math.Between -@turbofan, @turbofan
			@engine[thruster].startFollow(@model, true, 0.05, 0.05) for thruster of @engine

	turn: (speed) ->
		@model.body.setAngularVelocity speed

	orient: (dest, speed = 200) ->
		# Init setup.
		proj =  {x: dest.x, y: dest.y}
		# Bounds wrap.
		distfactor = 0.8
		if Math.abs(vdist=proj.x-@x) > @scene.physics.world.bounds.width * distfactor
			proj.x -= @scene.physics.world.bounds.width * Math.sign vdist
		if Math.abs(hdist=proj.y-@y) > @scene.physics.world.bounds.height * distfactor
			proj.y -= @scene.physics.world.bounds.height* Math.sign hdist
		# Actual course correction.
		angle = Phaser.Math.Angle.Between(@x, @y, proj.x, proj.y﻿)﻿
		delta = @model.rotation - angle - 3.14 * (if angle > 3.14 / 2 then -1.5 else 0.5)
		if Math.abs(delta) > 3.14 then delta = -delta
		@turn -(if Math.abs(delta) > speed/1000 then Math.sign(delta) * speed else delta)

	accel: (angle = @model.rotation - 3.14 / 2, impulse = @thrust) ->
		@model.body.setVelocityX(@model.body.velocity.x * 0.98).setVelocityY(@model.body.velocity.y * 0.98)
		@scene.physics.velocityFromRotation angle, impulse * @tempo, @acceleration
		@engine?.main.start()
		@thrusters = on

	propel: (impulse = @thrust) ->
		@accel()

	strafe: (to_right = false, impulse = @thrust) ->
		@accel @model.rotation-3.14*[0.75,0.25][0+to_right]
		@engine[if to_right then "deltaR" else "deltaL"].explode(3)

	shoot: (ammo, target) ->
		if --@ammo > 0 then @game.pending.push new ammo @game, @, target

	volume: (heardist = 1000) ->
		volume: Math.max 0,	(heardist - @remoteness) / heardist

	explode: (magnitude = 50) ->
		@explosion  = @game.explode.createEmitter
			speed: { min: magnitude * 0.9, max: magnitude * 1.1 }, scale: { start: 0.1, end: 0 }, blendMode: 'ADD'
		.explode magnitude * 2, @x, @y
		@model.first.setTintFill 0
		@model.body.destroy()
		@scene.tweens.add
			targets: @model, alpha: 0, ease: 'Power1', duration: 200, onComplete: () => @model.destroy()
		@engine[thruster].stopFollow().stop() for thruster of @engine
		@requiem?.play @volume()
		@alive = false

	update: () ->
		# Physics handler.
		@scene.physics.world.wrap @model, 0
		# Engines control
		if @engine?
			@engine.main.stop()
			[cos, sin] = [Math.cos(@model.rotation-3.14/2), Math.sin(@model.rotation-3.14/2)]
			@engine.main.followOffset.x	= -cos * @mengine_off
			@engine.main.followOffset.y	= -sin * @mengine_off
			for eng in "LR" when eng = @engine["delta" + eng]
				eng.followOffset.x = cos * @dengine_off
				eng.followOffset.y = sin * @dengine_off
		# Deacceleration.
		@model.body.setAngularVelocity 0
		@model.body.setAcceleration 0
		@model.body.setDrag(if @mass_damping then 0.95 else 1).useDamping = @mass_damping
		# Finalzation.
		@thrusters = off

	# --Properties goes here.
	@getter 'x',			() -> @model.x
	@getter 'y',			() -> @model.y
	@getter 'pos',			() -> @model.position
	@getter 'acceleration', () -> @model.body.acceleration
	@getter 'remoteness',	() -> Phaser.Math.Distance.Between @game.player.x, @game.player.y, @x, @y
# -------------------- #
class Player extends Body
	trashed:	0
	excl_zone: 	1050

	# --Methods goes here.
	constructor: (game, cfg, x = 0, y = 0) ->
		# Body setup.
		super 'pship', game, x, y, 'jet'
		@game.spacecrafts.add @model
		@model.setScale 0.15, 0.15
		@model.body.setMaxVelocity(100 * @tempo).setOffset(-65, -45).setSize(130, 130)
		@mengine_off += 4
		# Crosshair
		@target = @scene.add.container(0, 0).setDepth 3
		@target.add [
			@scene.add.image(0, 0, 'dest').setScale(0.08, 0.08).setAlpha(0.9)
			@scene.add.line(cfg.width / 2, 0, 0, 0, cfg.width * 3, 0, 0x50C878, 0.1),
			@scene.add.line(0, -cfg.height / 2, 0, 0, 0, cfg.height * 3, 0x50C878, 0.1)]
		@scene.tweens.add
			targets: @target.first, scaleX: 0.17, scaleY: 0.17, ease: 'Power1'
			duration: 300, repeat: -1, yoyo: true, repeatDelay: 500
		@target.visible = false
		# HUD setup (main & trash counters).
		hud_font = {fontFamily: 'Saira Stencil One', fontSize: 25}
		@hud = @scene.add.container 0, 0, (for color in ['gray', '#C46210']
			lbl = @scene.add.text(15, 15, '', hud_font).setColor color)
		.setScrollFactor(0).setDepth(2)
		# HUD setup (timer, threat, shadows, record).
		.add @scene.add.text(cfg.width / 2, 15, '', hud_font).setOrigin(0.5, 0)
		.add @scene.add.text(15, cfg.height-20, '', hud_font).setOrigin(0, 1)
		.add @scene.add.text(cfg.width / 2, cfg.height-20, '', hud_font).setOrigin(0.5, 1)
		lbl.setShadow(0, 0, "black", 7, true, true) for lbl in @hud.list
		# HUD setup (mass damping).
		@hud.add @damper = Game.text_switcher @game, cfg.width - 125, 12, "⥤⇌",
			(() -> @game.player.damping = not @game.player.damping), 
			((val) -> @setText("\n" + ["⥤", "⇌"][0 + val]).setColor ['slategray', '#31D2F7'][0 + val])
		@damping = JSON.parse(sessionStorage['damping'] ? 'true')
		# HUD setup (pause).
		@hud.add @switch = Game.text_switcher @game, cfg.width - 170, 14, @game.paused,
			(() -> @game.paused = not @game.paused), 
			((val) -> @setText "\n" + ["❚❚", ""][0 + val])
		@switch.setColor('gray')
		# HUD etup (ammo counter, threat gauge)
		@hud.add(@scene.add.text(cfg.width-65, cfg.height-30, '', hud_font).setOrigin(0.5, 0.5).setColor('#cb4154')
			.setShadow 0, 0, "crimson", 7, true, true)
		.add @scene.add.rectangle(15, cfg.height-20, 0, 0, 0xfffff).setOrigin(0, 1)
		# HUD setup (tweens).
		@beat_sfx = @scene.sound.add 'heartbeat'
		@hud.beat = @scene.tweens.add
			targets: @hud.list[7], scaleX: 0.9, scaleY: 1.2, duration: 75, yoyo: true, repeat: -1, repeatDelay: 935
			onRepeat: => @beat_sfx.play()
		# Finalization.
		@cam = game.maincam
		@cam.startFollow @model, true
		@departure = new Date()

	explode: () ->
		super()
		# HUD replacement.
		@scene.postmortem = @scene.add.container @scene.game.config.width/2, @scene.game.config.height/2, [
			@scene.add.text(0, 0, @hud.list[2].text.replace('.', ':')[2..-2], 
				{fontFamily: 'Saira Stencil One', fontSize: 100, color: 'crimson'}).setOrigin(0.5, 1)
					.setShadow(0, 0, "#cb4154", 7, true, true)
			@scene.add.text(0, 0, "☠"+@trashed, 
				{fontFamily: 'Saira Stencil One', fontSize: 100, color: 'crimson'}).setOrigin(0.5, 0)
					.setShadow(0, 0, "#cb4154", 7, true, true)
			@scene.add.rectangle(0, 0, 225, 5, 0xDC143C).setOrigin(0.5, 0.5)
		]
		@scene.postmortem.setScrollFactor(0).setAlpha(0).setScale(1, 0)		
		@scene.tweens.add
			targets: @scene.postmortem, alpha: 1, scaleY: 1, duration: 333, ease: 'Power1'
		@scene.tweens.add
			targets: @hud, alpha: 0, duration: 333, ease: 'Power1', onComplete: => @hud.destroy(); @hud.beat.remove()
		# Record data.
		@scene.postmortem.record = {time: @flytime, trashed: @trashed}
		# Other stuff.
		@target.destroy()
		@cam.fadeOut(1000)
		@cam.shake()

	notedeath: () ->
		return unless @alive
		@trashed++
		@game.spawnlag += Math.max 0, 300 - @trashed * 15
		@trash_anim = @scene.tweens.add
			targets: @hud.list[1], scaleY: 0.0, yoyo: true, duration: 300, ease: 'Power1'

	update: () ->
		super()
		tformat = (secs) ->	[secs // 60, secs % 60].map (f) -> "#{f}".padStart(2, '0')
		# Crosshair updating.
		Object.assign @target, @cam.getWorldPoint @scene.input.activePointer.position.x,
			@scene.input.activePointer.position.y
		@target.first.rotation -= 0.025
		# Controls.
		@target.visible = switch @game.controller
			when 'mouse'
				@orient @target
				@target.first.setTint if @scene.input.activePointer.isDown
					@propel()
					0x00FFFF
				else 0x708090
				true
			when 'keyboard'
				# Aux porcs.
				any_down = (keylist...) => for key in keylist then return true if @game.controls[key].isDown
				any_pressed = (keylist...) =>
					for key in keylist then return true if Phaser.Input.Keyboard.JustDown @game.controls[key]
				# Some init.
				pad = @scene.input.gamepad.getPad(0)
				[xshift, yshift] = if (axes = pad?.axes)? then [axes[0].getValue(), axes[1].getValue()] else [0, 0]
				# Common buttons.
				@damping = not @damping if (pad?.B and pad?.B isnt @B_prev) or any_pressed 'DOWN', 'S'					
				# Stccik/buttons switcher.
				if xshift or yshift then @orient {x: @x + xshift, y: @y + yshift}; @propel() # Stick control.
				else # Buttons control.
					# Turning.
					if pad?.left	or any_down 'LEFT',	'A'	then @turn -200
					if pad?.right 	or any_down 'RIGHT','D' then @turn 200
					# Directional movement.
					if		pad?.L1 or any_down 'Q'			then @strafe()
					else if pad?.R1	or any_down 'E'			then @strafe(true)
					else if pad?.A	or any_down 'UP', 'W'	then @propel()
				@B_prev = pad?._RCRight.pressed
				false
		# Mass damper.
		@turbofan = if @damping and @model.body.speed > 20 and not @thrusters
			@engine.deltaL.explode	intensity = @model.body.speed / 5
			@engine.deltaR.explode	intensity
			@engine.main.explode	@model.body.speed / 20
			20 * @model.body.speed / @model.body.maxVelocity.x
		else 
			@engine.main.setSpeed({ min: 50, max: -50}).setFrequency(0, 2).setScale({ start: 0.03, end: 0 })
			0
		# HUD update: trash counter.
		@hud.first.setColor (if 0 < @trash_anim?.progress < 1 then 'crimson' else @hud.list[1].scaleY = 1; 'gray')
		for lbl, idx in @hud.list[0..1]
			if idx is 0 or not (0 < @trash_anim?.progress < 0.5) then lbl.setText "Trashed: #{@trashed}☠"
		# HUD update: mission clock.
		msecs	= @flytime
		secs	= msecs // 1000
		@hud.list[2].setText ['🕐','🕑','🕒','🕓','🕔','🕕','🕖','🕗','🕘','🕙','🕚','🕛'][msecs // 100 % 12] +
			tformat(secs).join(':.'[msecs // 500 % 2]) + "\n"
		@hud.list[2].setColor('#f8' + Math.max(0x30, 0xef - secs).toString(16).padStart(2, '0').repeat(2))
		# HUD update: threat level.
		if @game.enemies is 0 then @hud.list[3].setText("No threat ?").setColor('#708090')
		else 
			rgb = Phaser.Display.Color.Interpolate.RGBWithRGB 0xFF,0xD7,0x00,0xDC,0x14,0x3C,5,Math.min(5, @game.enemies)
			@hud.list[3].setText("Threat: #{'🞖'.repeat(@game.enemies)}").setColor '#'	+
				(Math.round(rgb[comp]).toString(16).padStart(2, '0') for comp of rgb).join ''
		@hud.last.setSize(@game.spawnlag / 5, 3).fillColor = parseInt("0x"+@hud.list[3].style.color[1..])
		# HUD update: best record.
		best = @game.records
		{time, trashed}=(if best.length and @flytime < best[0].time then best[0] else {time:@flytime,trashed:@trashed})
		if @flytime >= time# or true
			@hud.list[4].setColor('crimson').setText "●#{@hud.list[2].text[2..-2]}⋮☠#{trashed}"
		else @hud.list[4].setColor('goldenrod').setText "🏆#{tformat(time//1000).join(':')}⋮☠#{trashed}"
		# HUD update: ammo counter.
		@hud.list[7].setText "Ammo:#{@ammo}"
		# Camera controls.
		@cam.setLerp(if @cam.worldView.contains(@x, @y) then 1 else 0.05)
		# Finalization.
		@alive

	# --Properties goes here.
	@getter 'damping', () -> @mass_damping
	@getter 'flytime', () -> new Date() - @departure
	@setter 'damping', (val) -> @damper.sync sessionStorage['damping'] = @mass_damping = val
# -------------------- #
class Missile extends Body
	fuel:	1000
	fused:	false

	# --Methods goes here.
	constructor: (game, emitter, @target) ->
		super 'rocket', game, emitter.x, emitter.y, 'jet'
		@model.setScale(0.15, 0.05).rotation = @scene.physics.accelerateToObject(@model, @target.model, 0) + 3.14 / 2
		@model.body.setMaxVelocity(110 * @tempo).setSize(100, 300).setOffset(-50, -150)
		@emitter	= emitter
		@mengine_off -= 1

	explode: () ->
		super()

	orient: (dest, speed = 90) ->
		super dest, speed

	update: () ->
		super()
		if @fuel-- > 0
			@orient @target.model
			@propel()
			@fused = true if not @fused and not @scene.physics.world.overlap(@model, @emitter.model)
		else if @fuel < -30 then @explode()
		if @alive and @fused then @scene.physics.world.overlap @model, @game.spacecrafts, (rkt, tgt) ->
			rkt.self.explode()
			tgt.self.explode()
		@alive
# -------------------- #
class MissileBase extends Body
	ammo:	Infinity
	ready:	false

	# --Methods goes here.
	constructor: (game, x, y) ->
		# Model setup
		super 'mbase', game, x, y
		@model.setScale(0.2)
		@model.body.setOffset(-200, -200).setSize(400, 400)
		# Additional setup.
		@game.spacecrafts.add @model
		@game.enemies++
		@reload	= 0
		# Missile silo.
		@silo	= @game.steam.createEmitter
			speed: {min: 50, max: 100}, scale: {start: 0.1,	end: 0.05},	alpha: {start: 1, end: 0}
			frequency: -1, blendMode: 'ADD'
		# Appearing.
		@teleport = @scene.tweens.add
			targets: @model, scaleX: {from: .0, to: .2}, alpha: {from: 0, to: 1}, duration: 1000, ease: 'Sine.easeInOut'
			#onComplete: => @ready = true
		.on 'complete', => @ready = true

	explode: () ->
		super 75
		@game.enemies--
		@game.player.notedeath()

	update: () ->
		super()
		return true unless @ready
		@turn 100
		if @reload++ is 100 and @shoot(Missile, @game.player)
			@silo.explode(80, @x, @y)
			@scene.sound.add("steam").on('completed', (snd) -> snd.destroy()).play(@volume())
			@reload = 0
		@scene.physics.world.overlap @model, @game.player.model, (bse, plr) ->
			bse.self.explode()
			plr.self.explode()
		@alive
# -------------------- #
class Game
	self		= null
	rnd:		Phaser.Math.Between
	paused_:	false

	# --Methods goes here.
	constructor: (width = 1024, height = 768) ->
		# Init setup.
		window.resizeTo Math.max(window.innerWidth, width+20), Math.max(window.innerHeight, height+45)
		window.moveTo (screen.width-window.outerWidth) / 2, (screen.height-window.outerHeight) / 2
		# Acutal game creation.		
		@app = new Phaser.Game
			type: Phaser.WEBGL, width: width, height: height, parent: 'main_ui'
			scale: {mode: Phaser.Scale.FIT, autoCenter: Phaser.Scale.CENTER_VERTICALLY}
			scene: {preload: @preload, create: @create.bind(@), update: @update.bind(@)}
			input: {gamepad: true}
			physics: 
				default: 'arcade'
				# arcade:
				# 	debug: true
			onPause: => @paused = true
		self = @

	preload: () ->
		self.scene = @
		@load.setPath "res/"
		for kind in ['rocket', 'mbase', 'pship']
			@load.image kind,				"#{kind}.png"
			@load.audio "explode:#{kind}",	"Explosion_#{kind}.wav"
		@load.image 'space',	'space.jpg'
		@load.image 'jet',		'flash00.png'
		@load.image 'steam',	'steam00.png'
		@load.image 'dest',		'dest.png'
		@load.image 'explode',	'explosion00.png'
		@load.audio 'steam',	'steam.wav'
		@load.audio 'heartbeat','heartbeat.wav'
		@load.audio "ambient:#{idx}", "Track#{idx}.ogg" for idx in [1..2]			

	create: () ->
		# Init setup.
		cfg		 = @app.config
		@maincam = @scene.cameras.main
		@space	 = @scene.add.tileSprite cfg.width / 2, cfg.height / 2, cfg.width*2, cfg.height*2, 'space'
		@spacecrafts = @scene.physics.add.group()
		@space.setScrollFactor(0)
		#@space.setAlpha 0.5
		# Particle setup.
		@[matter] = @scene.add.particles(matter) for matter in ['jet', 'explode', 'steam']
		@steam.setDepth(1)
		# Switchers.
		@schemer	= Game.text_switcher @, @app.config.width - 80, 14, "🖱️⌨️",
			(()		-> @game.controller = ['mouse', 'keyboard'].find (x) => x isnt @game.controller), 
			((val)	-> @setText "\n" + {mouse: "🖱️", keyboard: "⌨️"}[val])
		@muter		= Game.text_switcher @, @app.config.width - 35, 14, "🔊🔈",
			(()		-> @game.muted = not @game.muted),
			((val)	-> @setText "\n" + ["🔊", "🔈"][0 + val])
		@controller = localStorage['controller'] ? 'mouse'
		@muted		= JSON.parse(localStorage['muted'] ? 'false')
		# Ambient music.
		@track_list = []
		random = (-> (@now_playing = @[Phaser.Math.Between 0, @length-1]).play()).bind @track_list
		for vol, idx in [0.15, 0.4]
			@track_list.push @scene.sound.add("ambient:#{idx+1}",{volume: vol, delay: 5000}).on 'complete', random
		random()
		# Primary controls setup.
		@scene.input.setPollAlways true
		@controls = @scene.input.keyboard.addKeys('UP,LEFT,RIGHT,DOWN,W,S,A,D,Q,E')
		document.addEventListener 'keypress', (e) => if e.key is ' ' then @paused = not @paused
		setInterval (() => unless @welcome.visible
			btn = navigator.getGamepads()[0]?.buttons[9].touched
			if btn and btn isnt @start_prev then @paused = not @paused
			@start_prev = btn), 100
		# Additional main UI preparations.
		@main_id = document.getElementById 'main_ui'
		@main_id.style.visibility	= 'visible'
		@main_id.style.maxWidth		= "#{cfg.width}px"
		@main_id.style.maxHeight	= "#{cfg.height}px"
		# Utilitary UI preparations.
		@util_ui				= document.getElementById('util_ui')
		@util_ui.innerHTML		= "⋮▶Resume⋮"
		@util_ui.onpointerdown	= => @paused = false
		@util_ui.classList.add	'util_ui'
		window.addEventListener 'resize', => @util_ui.style.fontSize = "#{@scene.game.canvas.clientWidth/256}em"
		# Welcome GUI: logo.
		@welcome = @scene.add.container cfg.width / 2, cfg.height / 2, [
			@scene.add.text(0, 0, "Ammo:0", {fontFamily: 'Saira Stencil One', fontSize: 125, color: '#cb4154'})
				.setOrigin(0.5, 0.5).setShadow(0, 0, "crimson", 7, true, true)
			]
		@welcome.heart = @scene.sound.add('heartbeat', {volume: 0.8})
		@welcome.beat = @scene.tweens.add
			targets: @welcome.first, scaleX: 0.9, scaleY: 1.2, duration: 75, yoyo: true, repeat: -1, repeatDelay: 935
			onRepeat: => @welcome.heart.play() if @welcome.visible
		# Welcome GUI: desc.
		for hint, idx in ["「v0.04: Proto」", "「by Victoria A. Guevara」"]
			@welcome.add label = @scene.add.text((cfg.width/2)*[-1,1][idx], (cfg.height/2-20)*[-1,1][idx],
				hint, {fontFamily:'Titillium Web', fontSize:20}).setInteractive({useHandCursor:true}).setOrigin(idx,0.5)
			label.setStroke('#202020', 2)
			.on('pointerover',	(() -> @setShadow(0, 0, "darkcyan", 3, true, true).setColor 'cyan').bind label)
			.on('pointerout',	(() -> @setShadow(0, 0, "cyan", 4, true, true).setColor 'black').bind label)
			.on 'pointerdown', ((url) -> window.open url).bind @, 
				["https://github.com/Guevara-chan/Ammo-0", "https://vk.com/guevara_chan"][idx]
			label.setAlpha [0.4, 1][idx]
			@scene.tweens.add
				targets: label, alpha: [1, 0.4][idx], yoyo: true, repeat: -1, duration: 1000, ease: 'Sine.easeInOut'
			label.emit('pointerout')
		# Welcome GUI: hints.
		for idx in [0..1]
			@welcome.add lbl = @scene.add.text 0, [1,-1][idx]*(cfg.height/2-60), 
				"[click anywhere]·[press any key]·".repeat(6), 
					font = fontFamily: 'Titillium Web', fontSize: 35, color: 'coral'
			lbl.setAlpha(0.9).setOrigin(0.5, 0.5).setShadow(0, 0, "lightsalmon", 7, true, true)				
			@scene.tweens.add
				targets: lbl, x: [-300, 300][idx], yoyo: true, repeat: -1, duration: 5000, ease: 'Sine.easeInOut'
		# Finalization.
		@menu()

	cleanup: () ->
		obj.destroy() for obj in @scene.children.list[0..]	when obj.type is 'Container' and obj isnt @welcome
		snd.destroy() for snd in @scene.sound.sounds		when snd not in @track_list	 and snd isnt @welcome.heart

	menu: () ->
		# Init setup.
		@cleanup()
		@welcome.visible = true
		# Exeiting preparations.
		begin_game = () => unless @player? or @maincam.fadeEffect.isRunning
			@maincam.fadeOut 1000, 0, 0, 0, (camera, progress) =>
				if progress is 1 then [@player, @welcome.visible] = [{alive: false}, false]
		@space.setInteractive().once	'pointerdown',	begin_game
		@scene.input.gamepad.once		'down',			begin_game
		@scene.input.keyboard.once		'keydown',		key_check = (input) =>
			if input.code then begin_game() else @scene.input.keyboard.once	'keydown', key_check
		@mode = 'survival'; @zone = 'medium'

	init: (@mode, @zone) ->
		# Init setup.
		@cleanup()
		@objects	= []
		@enemies	= 0
		@player		= new Player @, @app.config
		# World setup.
		@edge			= {v: 250, h: 250}
		[width, height] = [2500, 2500]
		[x, y]			= [-width / 2, -height / 2]
		@scene.physics.world.setBounds	x, y, width, height
		@maincam.setBounds				x, y, width, height
		# Object placement.
		switch @mode
			when 'survival' # Legacy near enemy.
				@spawn MissileBase, {x: @player.x + 200 * [1,-1][@rnd 0, 1], y: @player.y + 200 * [1,-1][@rnd 0, 1]}
		# Briefing.
		lines = [
			"That guiding systems looks pretty cheap", "One day space will become endless again"
			"It's a little tough to find ammo here", "Eventually, I see this world crimson",
			"Pacifism is a form of violence", "Rockets, rockets, rockets", "That run will never end",
			"Just another bad dream", "Thou shalt not kill"
		]
		@briefing?.destroy()
		@briefing = @scene.add.text @player.x, @player.y - 40, "...#{lines[@rnd 0, lines.length-1]}...", 
				{fontFamily: 'Saira Stencil One', fontSize: 20, color: 'Cyan'}
		@briefing.setOrigin(0.5, 0.5).setShadow(0, 0, "lightcoral", 7, true, true)
		@scene.tweens.add cfg =
			targets: @briefing, alpha: 0, duration: 1300, scaleX: 0.6, y: @player.model.y, ease: 'Sine.easeInOut'
		# Spawning cache.
		{x, y, width, height}	= @scene.physics.world.bounds
		spawn_row				= [x+@edge.h...width/2-@edge.h]
		@spawner =
			area: ({y: idx, row: new Int32Array spawn_row} for idx in [y+@edge.v...height/2-@edge.v])
			proj:
				y: (coord) => coord + height / 2 - @edge.v
				x: (coord) => coord + width  / 2 - @edge.h
		# Finalization.
		@spawnlag		= 0
		@space.rotation = 0
		@maincam.fadeIn(1000)

	spawn: (kind = MissileBase, pos) ->
		unless pos?
			# Init setup.
			spawn_area	= [@spawner.area...]
			# Aux proc.
			cut_rect = (array, left, top, vlen, hlen) =>
				[left, top] = [Math.max(0, @spawner.proj.x left), Math.max(0, @spawner.proj.y top)]
				for idx in [top...Math.min(array.length-1, top + hlen)]
					pos = left
					arr = array[idx].row
					end = left+vlen
					arr[pos++] = 0 while pos < end
				return 0
			# Additional setup.
			for obj in @spacecrafts.children.entries when excl_zone = obj.self.excl_zone
				cut_rect spawn_area, obj.x // 1 - excl_zone // 2, obj.y // 1 - excl_zone // 2, excl_zone, excl_zone
			while true
				pos		= {y: @rnd 0, spawn_area.length-1}
				break if pos.x = (spawn_row = spawn_area[pos.y].row)[@rnd 0, spawn_row.length-1]
			pos.y	= spawn_area[pos.y].y
		# Actual spawning.
		@spawnlag += Math.max 0, 500 - @player.trashed * 25
		#console.log pos
		new kind @, pos.x, pos.y

	pause: () ->
		@player?.paused = new Date()
		@scene.game.canvas.style.opacity = 0.5
		@track_list.now_playing.pause()
		document.getElementById('util_ui').style.zIndex = 1
		@scene.scene.pause()

	unpause: () ->
		@util_ui.style.zIndex = -1
		@scene.game.canvas.style.opacity = 1
		@player?.departure = @player.departure - 0 + (new Date() - @player.paused)
		@track_list.now_playing.resume()
		@scene.scene.resume()

	note_record: (record) ->
		@best = @records
		@best.push record
		@best.sort (a, b) -> if a.time > b.time then -1 else 1
		localStorage[@records_key] = JSON.stringify @best[0..9]
		#console.log localStorage[@records_key]

	update: () ->
		[@space.tilePositionX, @space.tilePositionY] = [@maincam.scrollX, @maincam.scrollY]
		if @maincam.fadeEffect.isRunning then return
		else return @space.rotation -= 0.001 unless @player?
		if @player.alive # Updating objects.
			@pending = []
			switch @mode
				when 'survival' # Infinite missile bases spawn.
					if @enemies < 5 and (@spawnlag = Math.max 0, @spawnlag - 1) is 0 then @spawn()
			@objects = @objects.filter (obj) -> obj.alive and obj.update()
			@objects = @objects.concat @pending
		else # (Re)starting
			if @scene.postmortem 
				@note_record @scene.postmortem.record
				@scene.postmortem?.destroy()
			switch @mode
				when 'survival' # Infinite respawining.
					@init(@mode, @zone)

	@text_button: (game, x, y, click_handler, txt='') ->
		btn=game.scene.add.text(x,y,txt,{fontSize:35}).setScrollFactor(0).setInteractive().setDepth(2).setOrigin 0.5,0.5
		btn.on('pointerover', (-> unless @game.on_mobile
			@setShadow(0, 0, "darkcyan", 7, true, true).setStroke('cyan', 2).y-=1).bind btn)
		.on('pointerout',	(-> @setShadow(1, 1, "#330000", 1).setStroke('', 0).y+=1).bind btn)
		.on('pointerdown',	click_handler)
		.game = game
		return btn

	@text_switcher: (game, x, y, init_val, click_handler, switch_handler) ->
		btn				= Game.text_button game, x, y, click_handler
		btn.sync		= switch_handler?.bind btn
		btn.sync(init_val)
		return btn

	# --Properties goes here.
	@getter 'on_mobile',	() -> navigator.userAgent.match(/Android/i) or navigator.userAgent.match /iPhone|iPad|iPod/i
	@getter 'muted',		() -> @scene.sound.mute
	@getter 'controller',	() -> @controller_
	@getter 'paused',		() -> @paused_
	@getter 'records_key',	() -> "#{@mode}:#{@zone}:best"
	@getter 'records',		() -> JSON.parse(localStorage[@records_key] ? "[]")
	@setter 'muted',		(val) -> @muter.sync	localStorage['muted'] = @scene.sound.mute = val
	@setter 'controller',	(val) -> @schemer.sync	localStorage['controller'] = @controller_ = val
	@setter 'paused',		(val) -> @player?.switch.sync(val); if @paused_=val then @pause() else @unpause()
#.}

# ==Main code==
new Game()