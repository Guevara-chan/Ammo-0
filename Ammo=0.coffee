# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# Ammo:0 antishooter game v0.03
# Developed in 2019 by V.A. Guevara
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

#.{ [Classes]
class Body
	alive:	true
	ammo:	0

	# --Methods goes here.
	constructor: (@sprite_id, @game, x, y, trail_id) ->
		# Init setup.
		@scene		= @game.scene
		@model		= @scene.physics.add.existing @scene.add.container x, y, [@scene.add.image(0, 0, @sprite_id)]
		@requiem	= @scene.sound.add("explode:#{@sprite_id}").on 'complete', (snd) -> snd.destroy()
		@model.self	= @
		# Trail setup.
		if trail_id?
			@trail = @game[trail_id].createEmitter cfg =
				speed: 100, scale: { start: 0.02, end: 0 },	blendMode: 'ADD', on: false, angle: () => @model.angle + 90
			.startFollow @model, true, 0.05, 0.05

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
		@model.body.setAngularVelocity -(if Math.abs(delta) > speed/1000 then Math.sign(delta) * speed else delta)

	propel: (impulse) ->
		@model.body.setVelocityX(@model.body.velocity.x *0.98).setVelocityY(@model.body.velocity.y * 0.98)
		@scene.physics.velocityFromRotation(@model.rotation - 3.14 / 2, impulse, @acceleration)
		@trail?.start()

	shoot: (ammo, target) ->
		if --@ammo > 0 then @game.pending.push new ammo @game, @, target

	volume: (heardist = 1000) ->
		volume: Math.max 0,	(heardist - @remoteness) / heardist

	explode: (magnitude = 50) ->
		@explosion  = @game.explode.createEmitter
			speed: { min: magnitude * 0.9, max: magnitude * 1.1 }, scale: { start: 0.1, end: 0 }, blendMode: 'ADD'
		.explode(magnitude * 2, @x, @y)
		@model.destroy()
		@trail?.stopFollow().stop()
		@requiem?.play @volume()
		@alive = false

	update: () ->
		@scene.physics.world.wrap @model, 0
		@trail?.stop()
		@trail?.followOffset.x = -@acceleration.x / 10
		@trail?.followOffset.y = -@acceleration.y / 10

	# --Properties goes here.
	@getter 'x',			() -> @model.x
	@getter 'y',			() -> @model.y
	@getter 'acceleration', () -> @model.body.acceleration
	@getter 'remoteness',	() -> Phaser.Math.Distance.Between(@game.player.x, @game.player.y, @x, @y)
# -------------------- #
class Player extends Body
	trashed: 0

	# --Methods goes here.
	constructor: (game, cfg, x = 0, y = 0) ->
		# Body setup.
		super 'pship', game, x, y, 'jet'
		@game.spacecrafts.add @model
		@model.setScale 0.15, 0.15
		@model.body.setMaxVelocity(100).setOffset(-65, -45).setSize(130, 130).setDrag(0.95).useDamping = true
		# Custom jet trail.
		@trail.setSpeed({ min: 50, max: -50}).setFrequency(0, 2).setScale({ start: 0.03, end: 0 })
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
		# HUD setup (pause).
		@hud.add @switch = Game.text_button @scene, cfg.width - 80, 14, () =>
			if @switch.state isnt 0 then @game.pause()
			@switch.setText "\n"+["", "❚❚"][@switch.state = 1 - @switch.state]
		@switch.setColor('gray').state = 0
		@switch.emit('pointerdown')
		# Hud setup (ammo counter, threat gauge)
		@hud.add(@scene.add.text(cfg.width-65, cfg.height-30, '', hud_font).setOrigin(0.5, 0.5).setColor('#cb4154')
			.setShadow 0, 0, "crimson", 7, true, true)
		.add @scene.add.rectangle(15, cfg.height-20, 0, 0, 0xfffff).setOrigin(0, 1)
		# HUD setup (tweens).
		@beat_sfx = @scene.sound.add 'heartbeat'
		@hud.beat = @scene.tweens.add
			targets: @hud.list[6], scaleX: 0.9, scaleY: 1.2, duration: 75, yoyo: true, repeat: -1, repeatDelay: 935
			onRepeat: => @beat_sfx.play()
		# Finlization.
		@scene.cameras.main.startFollow @model, true, 0.05, 0.05
		@departure = new Date()

	explode: () ->
		super()
		# HUD replacement.
		@scene.postmortem = @scene.add.container 1024/2, 768/2, [
			@scene.add.text(0, 0, @hud.list[2].text.replace('.', ':')[2..], 
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
		@scene.cameras.main.fadeOut(1000)
		@scene.cameras.main.shake()

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
		Object.assign @target, @scene.cameras.main.getWorldPoint @scene.input.activePointer.position.x,
			@scene.input.activePointer.position.y
		@target.first.rotation -= 0.025
		@orient @target
		@model.body.setAcceleration(0)
		# Controls.
		@target.first.setTint if @scene.input.activePointer.isDown
			@propel(200)
			0x00FFFF
		else 0x708090
		# HUD update: trash counter.
		@hud.first.setColor (if 0 < @trash_anim?.progress < 1 then 'crimson' else @hud.list[1].scaleY = 1; 'gray')
		for lbl, idx in @hud.list[0..1]
			if idx is 0 or not (0 < @trash_anim?.progress < 0.5) then lbl.setText "Trashed: #{@trashed}☠"
		# HUD update: mission clock.
		msecs	= @flytime
		secs	= msecs // 1000
		@hud.list[2].setText ['🕐','🕑','🕒','🕓','🕔','🕕','🕖','🕗','🕘','🕙','🕚','🕛'][msecs // 100 % 12] +
			tformat(secs).join ':.'[msecs // 500 % 2]
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
			@hud.list[4].setColor('crimson').setText "●#{@hud.list[2].text[2..]}⋮☠#{trashed}"
		else @hud.list[4].setColor('goldenrod').setText "🏆#{tformat(time//1000).join(':')}⋮☠#{trashed}"
		# HUD update: ammo counter.
		@hud.list[6].setText "Ammo:#{@ammo}"
		# Finalization.
		@target.visible = true
		@alive

	# --Properties goes here.
	@getter 'flytime', () -> new Date() - @departure
# -------------------- #
class Missile extends Body
	fuel:	1000
	fused:	false

	# --Methods goes here.
	constructor: (game, emitter, @target) ->
		super 'rocket', game, emitter.x, emitter.y, 'jet'
		@model.setScale(0.15, 0.05).rotation = @scene.physics.accelerateToObject(@model, @target.model, 0) + 3.14 / 2
		@model.body.setMaxVelocity(110).setSize(100, 300).setOffset(-50, -150)#.setDrag(1).useDamping = true
		@emitter = emitter

	explode: () ->
		super()

	orient: (dest, speed = 90) ->
		super dest, speed

	update: () ->
		super()
		if @fuel-- > 0
			@orient @target.model
			@propel(200)
			@fused = true if not @fused and not @scene.physics.world.overlap(@model, @emitter.model)
		else if @fuel < -30 then @explode()
		if @alive and @fused then @scene.physics.world.overlap @model, @game.spacecrafts, (rkt, tgt) ->
			rkt.self.explode()
			tgt.self.explode()
		@alive
# -------------------- #
class MissileBase extends Body
	ammo: Infinity

	# --Methods goes here.
	constructor: (game, x, y) ->
		# Model setup
		super 'mbase', game, x, y
		@model.setScale(0.0, 0.2).alpha = 0
		@model.body.setOffset(-200, -200).setSize(400, 400)
		# Additional setup.
		@game.spacecrafts.add(@model)
		@game.enemies++
		@reload	= 0
		# Missile silo
		@silo	= @game.steam.createEmitter cfg =
			speed: { min: 50,		max: 100 }
			scale: { start: 0.1,	end: 0.05 }
			alpha: { start: 1,		end: 0 }
			frequency: -1
			blendMode: 'ADD'
		# Appearing.
		@teleport = @scene.tweens.add cfg =
			targets: @model,
			scaleX: 0.2
			alpha: 1 # { start: 0, end: 1}
			duration: 1000,
			ease: 'Sine.easeInOut'

	explode: () ->
		super 75
		@game.enemies--
		@game.player.notedeath()

	update: () ->
		super()
		return true unless @teleport.progress is 1
		@model.body.setAngularVelocity(100)
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
	self = null
	rnd: Phaser.Math.Between

	# --Methods goes here.
	constructor: (width = 1024, height = 768) ->
		window.resizeTo Math.max(window.innerWidth, width+20), Math.max(window.innerHeight, height+45)
		window.moveTo (screen.width-window.outerWidth) / 2, (screen.height-window.outerHeight) / 2
		@app = new Phaser.Game
			type: Phaser.WEBGL, width: width, height: height, parent: 'vp'
			scale: {mode: Phaser.Scale.SHOW_ALL, autoCenter: Phaser.Scale.CENTER_BOTH}

			scene: {preload: @preload, create: @create.bind(@), update: @update.bind(@)}
			physics: 
				default: 'arcade'
				# arcade:
				# 	debug: true
			onPause: @pause.bind @
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
		@load.audio "ambient:#{idx}", "Track#{idx}.ogg" for idx in [1..3]			

	create: () ->
		# Init setup.
		cfg		= @app.config
		@space	= @scene.add.tileSprite cfg.width / 2, cfg.height / 2, cfg.width*2, cfg.height*2, 'space'
		@spacecrafts = @scene.physics.add.group()
		@space.setScrollFactor(0)
		# Particle setup.
		@[matter] = @scene.add.particles(matter) for matter in ['jet', 'explode', 'steam']
		@steam.setDepth(1)
		# SFX switcher.
		@muter = Game.text_button @scene, @app.config.width - 35, 14, () ->
			@scene.sound.setMute @state; @setText "\n"+["🔈", "🔊"][@state = 1 - @state]
		@muter.state = 0
		@muter.emit('pointerdown')
		# Ambient music.
		@track_list = []
		random = (-> (@now_playing = @[Phaser.Math.Between 0, @length-1]).play()).bind @track_list
		for vol, idx in [0.15, 0.4]
			@track_list.push @scene.sound.add("ambient:#{idx+1}",{volume: vol, delay: 5000}).on 'complete', random
		random()
		# Additional main UI preparations.
		@scene.input.setPollAlways true
		document.getElementById('main_ui').style.visibility = 'visible'
		# Utilitary UI preparations.
		@util_ui				= document.getElementById('util_ui')
		@util_ui.innerHTML		= "⋮▶Resume⋮"
		@util_ui.onpointerdown	= @unpause.bind @
		@util_ui.classList.add	'util_ui'
		# Welcome GUI: logo.
		@welcome = @scene.add.container cfg.width / 2, cfg.height / 2, [
			@scene.add.text(0, 0, "Ammo:0", {fontFamily: 'Saira Stencil One', fontSize: 125, color: '#cb4154'})
				.setOrigin(0.5, 0.5).setShadow(0, 0, "crimson", 7, true, true)
			]
		@welcome.heart = @scene.sound.add('heartbeat', {volume: 0.8})
		@welcome.beat = @scene.tweens.add
			targets: @welcome.first, scaleX: 0.9, scaleY: 1.2, duration: 75, yoyo: true, repeat: -1, repeatDelay: 935
			onRepeat: => @welcome.heart.play()
		# Welcome GUI: desc.
		for hint, idx in ["「v0.03: Proto」", "「by Victoria A. Guevara」"]
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
			@welcome.add lbl = @scene.add.text 0, [1,-1][idx]*(cfg.height/2-60), "[click anywhere]·".repeat(15), font =
				fontFamily: 'Titillium Web', fontSize: 35, color: 'coral'
			lbl.setAlpha(0.9).setOrigin(0.5, 0.5).setShadow(0, 0, "lightsalmon", 7, true, true)				
			@scene.tweens.add
				targets: lbl, x: [-300, 300][idx], yoyo: true, repeat: -1, duration: 5000, ease: 'Sine.easeInOut'
		@space.setInteractive().once 'pointerdown', () =>
			@scene.cameras.main.fadeOut(1000); @player = {alive: false}
		# Game mode setup.
		@mode = 'survival'; @zone = 'medium'

	init: (@mode, @zone) ->
		# Init setup.
		obj.destroy() for obj in @scene.children.list[0..] when obj.type is 'Container'
		snd.destroy() for snd in @scene.sound.sounds when snd not in @track_list
		@objects	= []
		@enemies	= 0
		@objects.push @player = new Player @, @app.config
		# World setup.
		[width, height] = [2500, 2500]
		[x, y]			= [-width / 2, -height / 2]
		@scene.physics.world.setBounds	x, y, width, height
		@scene.cameras.main.setBounds	x, y, width, height
		# Object placement.
		switch @mode
			when 'survival' # Legacy near enemy.
				@spawn @player.x + 200 * [1,-1][@rnd 0, 1], @player.y + 200 * [1,-1][@rnd 0, 1]
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
		# Finalization.
		@welcome?.destroy()
		@welcome?.beat.remove()
		@spawnlag		= 0
		@space.rotation = 0
		@scene.cameras.main.fadeIn(1000)

	spawn: (x, y) ->
		{width, height} = @scene.physics.world.bounds		
		x = @player.x + @rnd(@app.config.width / 2, width - @app.config.width)	unless x?
		y = @player.y + @rnd(@app.config.height / 2, height - @app.config.height) unless y?
		@objects.push @enemy = new MissileBase @, x, y
		@spawnlag += Math.max 0, 500 - @player.trashed * 25

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
		@player?.switch.emit('pointerdown')
		@track_list.now_playing.resume()
		@scene.scene.resume()

	note_record: (record) ->
		@best = @records
		@best.push record
		@best.sort (a, b) -> if a.time > b.time then -1 else 1
		localStorage[@records_key] = JSON.stringify @best[0..9]
		console.log localStorage[@records_key]

	update: () ->
		[@space.tilePositionX, @space.tilePositionY] = [@scene.cameras.main.scrollX, @scene.cameras.main.scrollY]
		if @scene.cameras.main.fadeEffect.isRunning then return
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

	@text_button: (scene, x, y, click_handler, txt='') ->
		btn=scene.add.text(x, y, txt,{fontSize: 35}).setScrollFactor(0).setInteractive().setDepth(2).setOrigin(0.5, 0.5)
		btn.on('pointerover',	(-> @setShadow(0, 0, "darkcyan", 7, true, true).setStroke('cyan', 2).y-=1).bind btn)
		.on('pointerout',	(-> @setShadow(1, 1, "#330000", 1).setStroke('', 0).y+=1).bind btn)
		.on('pointerdown',	click_handler)
		return btn

	# --Properties goes here.
	@getter 'records_key',	() -> "#{@mode}:#{@zone}:best"
	@getter 'records',		() -> JSON.parse(localStorage[@records_key] ? "[]")
#.}

# ==Main code==
new Game()