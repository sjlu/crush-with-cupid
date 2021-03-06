class Search
	constructor: ->
		@access_token = FB.getAuthResponse()['accessToken']
		@populate()

		toggleBackToTop = _.debounce (e) ->
			if $('#back-to-top').is(":visible")
				if $(window).scrollTop() <= $('#friends').position().top
					$('#back-to-top').hide("slide", { direction: "right" }, 500);
			else
				if $(window).scrollTop() >= $('#friends').position().top
					$('#back-to-top').show("slide", { direction: "right" }, 500);
		, 250

		# binding scroll event.
		$(window).scroll toggleBackToTop
		$('#back-to-top').click ->
			$('html, body').animate
         		scrollTop: $('#filters').offset().top-20
     		, 500

     	@searchBy = null

		FB.api '/me', (response) =>
			@filterBy = 'all'
			if response.gender == 'female' 
				@filterBy = 'male' 
			else if response.gender == 'male'
				@filterBy = 'female'
			$("#filters ##{@filterBy}").addClass('active');
			@render()

	reset: ->
		@friends = null
		@crushes = null
		@pairs = null

	populate: ->
		@reset()

		$.ajax '/crushes'
			dataType: "json"
			success: (response) =>
				@crushes = response
				@render()
			error: =>
				@crushes = []

		$.ajax '/pairs'
			dataType: "json"
			success: (response) =>
				@pairs = response
				@render()
			error: =>
				@pairs = []

		FB.api
			method: 'fql.query',
			query: 'SELECT uid, name, sex FROM user WHERE uid IN (SELECT uid2 FROM friend WHERE uid1 = me())'
			(response) =>
				@friends = response
				@render()

	add: (fbid, elem) =>
		@crushes.push(fbid);

		$.ajax '/crushes'
			type: 'POST'
			dataType: 'json'
			data: 
				to: fbid
			success: (response) =>
				if response.paired?
					@pairs.push(fbid)
					elem.addClass('pair')
					elem.find('.photo').append("<img class='pair' src='assets/img/pair.png' />")


	remove: (fbid) ->
		@crushes.splice(_.indexOf(@crushes, fbid), 1)

		$.ajax '/crushes'
			type: 'DELETE'
			dataType: 'json'
			data: 
				to: fbid

	bind: ->
		that = this;
		$('.pick').click ->
			fbid = $(@).attr('data-uid');
			elem = $(@).closest(".friend")

			if elem.hasClass('pair')
				return

			if (_.contains(that.crushes, fbid))
				elem.removeClass('picked');
				that.remove(fbid)
			else
				elem.addClass('picked');
				that.add(fbid, elem)

		searchAction = _.debounce ->
			searchBy = $('#search-query').val()
			console.log(searchBy)

			if not searchBy? or searchBy == ''
				return;

			$("#filters ##{that.filterBy}").removeClass('active');
			that.filterBy = 'search'

			if searchBy != that.searchBy
				that.searchBy = searchBy
				that.render()
		, 500

		$('#search-query').keypress searchAction
		$('#search-query').focus searchAction

		$('#filters div, #filters #all, #filters i').click ->
			filterBy = $(@).attr('data-filter')

			if filterBy != that.filterBy or that.searchBy?
				that.searchBy = null	
				$("#filters ##{that.filterBy}").removeClass('active');
				$(@).addClass('active');
				that.filterBy = filterBy
				that.render()

	filter: (friends) =>
		filtered = @friends

		if @filterBy == 'heart'
			filtered = _.filter filtered, (friend) =>
				_.contains(@crushes, friend.uid)
		else if @filterBy == 'male' || @filterBy == 'female'
			filtered = _.where(filtered, {sex: @filterBy});
		else if @filterBy == 'search'
			if @searchBy?
				regexp = new RegExp(@searchBy, "i")
				filtered = _.filter filtered, (friend) =>
					if friend.name.search(regexp) > -1
						return true
					return false

		filtered

	render: () ->		
		if not @friends? or not @crushes? or not @filterBy? or not @pairs?
			return

		filtered = @filter()

		$('#friends').fadeOut =>
			$('#friends').html ''
			_.each filtered, (friend) =>
				photo = "https://graph.facebook.com/#{friend.uid}/picture?height=320&width=320&access_token=#{@access_token}"
				@renderOne(friend, _.contains(@crushes, friend.uid), _.contains(@pairs, friend.uid), photo)

			$('#rundown').fadeIn();
			$('#friends').fadeIn =>
				@bind()

	renderOne: (friend, has_crush, is_pair, photo) ->
		picked = ''
		if (has_crush)
			picked = 'picked'

		pair = ''
		if (is_pair)
			pair = 'pair'

		content = 	"<div class='friend #{picked} #{pair}'>" +
						"<div class='content'>" +
							"<div class='photo'>" + 
								"<img src='#{photo}' />"
		
		if (is_pair)
			content += "<img class='pair' src='assets/img/pair.png' />"

		content +=			"</div>" + 
							"<p>#{friend.name}</p>" +
							"<a data-uid='#{friend.uid}' class='pick #{picked}'><i class='icon-heart'></i>Crush</a>" +
						"</div>" +
					"</div>";

		$('#friends').append(content);
