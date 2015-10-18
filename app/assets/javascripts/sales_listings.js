SalesListings = {};

(function() {
	// for searching on the index page
	SalesListings.doSearch = function (sort_by_col, sort_direction) {
		Listings.showSpinner();

		//console.log(sort_by_col, sort_direction);
		// sanitize invalid input before submitting
	  if ($('#sales #neighborhood_ids').val() == "{:id=>\"neighborhood_ids\"}") {
	    $('#sales #neighborhood_ids').val('');
	  }
	  if ($('#sales #building_feature_ids').val() == "{:id=>\"building_feature_ids\"}") {
	    $('#sales #building_feature_ids').val('');
	  }
	  if ($('#sales #unit_feature_ids').val() == "{:id=>\"unit_feature_ids\"}") {
	    $('#sales #unit_feature_ids').val('');
	  }

	  var search_path = $('#sales-search-filters').attr('data-search-path');

	  $.ajax({
	    url: search_path,
	    data: {
        address: $('#sales #address').val(),
        unit: $('#sales #unit').val(),
        price_min: $('#sales #price_min').val(),
        price_max: $('#sales #price_max').val(),
        bed_min: $('#sales #bed_min').val(),
        bed_max: $('#sales #bed_max').val(),
        bath_min: $('#sales #bath_min').val(),
        bath_max: $('#sales #bath_max').val(),
        landlord: $('#sales #landlord').val(),
        pet_policy_shorthand: $('#sales #pet_policy_shorthand').val(),
        available_starting: $('#sales #available_starting').val(),
        available_before: $('#sales #available_before').val(),
        status: $('#sales #status').val(),
        features: $('#sales #features').val(),
        has_fee: $('#sales #has_fee').val(),
        neighborhood_ids: $('#sales #neighborhood_ids').val(),
        unit_feature_ids: $('#sales #unit_feature_ids').val(),
        building_feature_ids: $('#sales #building_feature_ids').val(),
        sort_by: sort_by_col,
        direction: sort_direction,
	    },
	    dataType: 'script',
	    success: function(data) {
	    	//console.log('SUCCESS:', data.responseText);
	    	Listings.hideSpinner();
			},
			error: function(data) {
				//console.log('ERROR:', data.responseText);
				Listings.hideSpinner();
			}
	  });
	};

	SalesListings.setupSortableColumns = function() {
		$('#sales .th-sortable').click(function(e) {
			e.preventDefault();
			
			if ($(this).hasClass('selected-sort')) {
				// switch sort order
				var i = $('.selected-sort i');
				if (i) {
					if (i.hasClass('glyphicon glyphicon-triangle-bottom')) {
						i.removeClass('glyphicon glyphicon-triangle-bottom').addClass('glyphicon glyphicon-triangle-top');
						$(this).attr('data-direction', 'desc');
					}
					else if (i.hasClass('glyphicon glyphicon-triangle-top')) {
						i.removeClass('glyphicon glyphicon-triangle-top').addClass('glyphicon glyphicon-triangle-bottom');
						$(this).attr('data-direction', 'asc');
					}
				}
			} else {
				// remove selection from old row
				$('.selected-sort').attr('data-direction', '');
				$('th i').remove(); // remove arrows
				$('.selected-sort').removeClass('selected-sort');
				// select new column
				$(this).addClass('selected-sort').append(' <i class="glyphicon glyphicon-triangle-bottom"></i>');
				$(this).attr('data-direction', 'asc');
			}

			var sort_by_col = $(this).attr('data-sort');
			var sort_direction = $(this).attr('data-direction');
			SalesListings.doSearch(sort_by_col, sort_direction);
		});
	};

	// search as user types
	SalesListings.timer;
	SalesListings.throttledSearch = function () {
		//console.log('throttling?');
		//clear any interval on key up
		if (SalesListings.timer) {
			//console.log('yes, clearing');
		  clearTimeout(SalesListings.timer);
		}
	  SalesListings.timer = setTimeout(SalesListings.doSearch, 500);
	};

	// change enter key to tab
	SalesListings.preventEnter = function (event) {
	  if (event.keyCode == 13) {
	    //$('#checkbox_active').focus();
	    return false;
	  }
	};

	SalesListings.initializeDocumentsDropzone = function() {
    // grap our upload form by its id
    $("#sunit-dropzone-docs").dropzone({
      // show remove links on each image upload
      addRemoveLinks: true,
      // if the upload was successful
      success: function(file, response){
        // find the remove button link of the uploaded file and give it an id
        // based of the fileID response from the server
        $(file.previewTemplate).find('.dz-remove').attr('id', response.fileID);
        $(file.previewTemplate).find('.dz-remove').attr('sunit_id', response.cunitID);
        // add the dz-success class (the green tick sign)
        $(file.previewElement).addClass("dz-success");
        $.getScript('/sales_listings/' + response.cunitID + '/refresh_documents')
        file.previewElement.remove();
      },
      //when the remove button is clicked
      removedfile: function(file){
        // grap the id of the uploaded file we set earlier
        var id = $(file.previewTemplate).find('.dz-remove').attr('id'); 
        var unit_id = $(file.previewTemplate).find('.dz-remove').attr('unit_id');
        DropZoneHelper.removeDocument(id, unit_id, 'sales_listings');
        file.previewElement.remove();
      }
    });

    DropZoneHelper.updateRemoveDocLinks('sales', 'sales_listings');

    // $('.carousel-indicators > li:first-child').addClass('active');
    // $('.carousel-inner > .item:first-child').addClass('active');

    DropZoneHelper.setPositions('sales', 'documents');
    DropZoneHelper.makeSortable('sales', 'documents');

    // after the order changes
    $('#sales .documents.sortable').sortable().bind('sortupdate', function(e, ui) {
        // array to store new order
        updated_order = []
        // set the updated positions
        DropZoneHelper.setPositions('sales', 'documents');
        
        // populate the updated_order array with the new task positions
        $('.doc').each(function(i){
          updated_order.push({ id: $(this).data('id'), position: i+1 });
        });
        // send the updated order via ajax
        var cunit_id = $('#sales').attr('data-sunit-id');
        $.ajax({
          type: "PUT",
          url: '/sales_listings/' + cunit_id + '/documents/sort',
          data: { order: updated_order }
        });
    });
  };

  SalesListings.initializeImageDropzone = function() {
    // grap our upload form by its id
    $("#sunit-dropzone").dropzone({
      // restrict image size to a maximum 1MB
      //maxFilesize: 4,
      //paramName: "upload[image]",
      // show remove links on each image upload
      addRemoveLinks: true,
      // if the upload was successful
      success: function(file, response){
        // find the remove button link of the uploaded file and give it an id
        // based of the fileID response from the server
        $(file.previewTemplate).find('.dz-remove').attr('id', response.fileID);
        $(file.previewTemplate).find('.dz-remove').attr('sunit_id', response.cunitID);
        // add the dz-success class (the green tick sign)
        $(file.previewElement).addClass("dz-success");
        $.getScript('/sales_listings/' + response.cunitID + '/refresh_images')
        file.previewElement.remove();
      },
      //when the remove button is clicked
      removedfile: function(file){
        // grap the id of the uploaded file we set earlier
        var id = $(file.previewTemplate).find('.dz-remove').attr('id'); 
        var unit_id = $(file.previewTemplate).find('.dz-remove').attr('unit_id');
        DropZoneHelper.removeImage(id, unit_id, 'sales_listings');
        file.previewElement.remove();
      }
    });

    DropZoneHelper.updateRemoveImgLinks('sales', 'sales_listings');

    $('.carousel-indicators > li:first-child').addClass('active');
    $('.carousel-inner > .item:first-child').addClass('active');

    DropZoneHelper.setPositions('sales', 'images');
    DropZoneHelper.makeSortable('sales', 'images');

    // after the order changes
    $('#sales .sortable').sortable().bind('sortupdate', function(e, ui) {
        // array to store new order
        updated_order = []
        // set the updated positions
        DropZoneHelper.setPositions('sales', 'images');
        
        // populate the updated_order array with the new task positions
        $('.img').each(function(i) {
          updated_order.push({ id: $(this).data('id'), position: i+1 });
        });
        //console.log(updated_order);
        // send the updated order via ajax
        var cunit_id = $('#sales').attr('data-sunit-id');
        $.ajax({
          type: "PUT",
          url: '/sales_listings/' + cunit_id + '/unit_images/sort',
          data: { order: updated_order }
        });
    });
  };

	SalesListings.removeUnitFeature = function (event) {
  	event.preventDefault();
	  var feature_id = $(this).attr('data-id');
  	var idx = $('#sales #unit_feature_ids').val().indexOf(feature_id);
  	//console.log(feature_id, idx, feature_id.length, $('#unit_feature_ids').val());
  	$('#sales #unit_feature_ids').val( $('#sales #unit_feature_ids').val().replace(feature_id, '') );
  	//console.log('new val is', $('#unit_feature_ids').val() );
  	$(this).remove();
  	SalesListings.throttledSearch();
  };

  SalesListings.removeBuildingFeature = function (event) {
  	event.preventDefault();
	  var feature_id = $(this).attr('data-id');
  	var idx = $('#sales #building_feature_ids').val().indexOf(feature_id);
  	$('#sales #building_feature_ids').val( $('#sales #building_feature_ids').val().replace(feature_id, '') );
  	$(this).remove();
  	SalesListings.throttledSearch();
  };

  SalesListings.removeNeighborhood = function (event) {
  	event.preventDefault();
	  var feature_id = $(this).attr('data-id');
  	var idx = $('#sales #neighborhood_ids').val().indexOf(feature_id);
  	$('#sales #neighborhood_ids').val( $('#sales #neighborhood_ids').val().replace(feature_id, '') );
  	$(this).remove();
  	SalesListings.throttledSearch();
  };

	// for giant google map
	SalesListings.buildContentString = function (key, info) {
	  var contentString = '<strong>' + key + '</strong><br />'; //<hr />';
	  for (var i=0; i<info['units'].length; i++) {
	    contentString += '<a href="https://myspace-realty-monster.herokuapp.com/sales_listings/' + info['units'][i].id + '">#' + info['units'][i].building_unit + '</a> ' + info['units'][i].beds + ' bd / ' 
	      + info['units'][i].baths + ' baths $' + info['units'][i].rent + '<br />';
	    if (i == 5) {
	      contentString += '<a href="https://myspace-realty-monster.herokuapp.com/sales_listings?building_id=' + info['building_id'] + '">View more...</a>';
	      break;
	    }
	  }
	  return contentString;
	};

	// SalesListings.map;
	// SalesListings.overlays;

	// SalesListings.updateOverviewMap = function(in_data) {
	// 	SalesListings.overlays.clearLayers();
 //    var markers = new L.MarkerClusterGroup({
 //    	maxClusterRadius: 30 // lean towards showing more individual markers
 //    }).addTo(SalesListings.overlays);//{ showCoverageOnHover: false });
		
 //    var dataPoints;
	//   // if updating from an ajax call, in_data will hava content.
	//   // we load data from a data attribute on page load, but that remains cached forever -
	//   // it will not update with subsequent ajax calls.
	//   if (in_data) {
	//   	dataPoints = JSON.parse(in_data);
	//   } else {
	//   	dataPoints = JSON.parse($('#big-map').attr('data-map-points'));
	//   }

	//   var features = [];
	//   Object.keys(dataPoints).forEach(function(key, index) {
	//     // draw each marker + load with data
	//     var info = dataPoints[key];

	//     var content = SalesListings.buildContentString(key, info);
	//     var marker = L.marker(new L.LatLng(info.lat, info.lng), {
	//       icon: L.mapbox.marker.icon({
	//       	'marker-size': 'small', 
	//       	'marker-color': '#f86767'
	//       }),
	//       'title': key,
	//     });
	//     marker.bindPopup(content);
 //      markers.addLayer(marker);
	//     // var feature = {
 //     //    type: 'Feature',
 //     //    properties: {
 //     //        title: key,
 //     //        'marker-color': '#f86767',
 //     //        'description': SalesListings.buildContentString(key, info),
 //     //        'marker-size': 'small'
 //     //    },
 //     //    geometry: {
 //     //        type: 'Point',
 //     //        coordinates: [info.lng, info.lat]
 //     //    }
 //    	// };
    	
 //    	// features.push(feature);
	// 	});

	// 	var geojson = {
	// 		'type': 'FeatureCollection',
	// 		'features': features
	// 	};

 //    //markerLayer.setGeoJSON(geojson);
 //    var geoJsonLayer = L.geoJson(geojson);
 //    //geoJsonLayer.clearLayers();
 //    markers.addLayer(geoJsonLayer);
 // 		SalesListings.map.addLayer(markers);
 //    SalesListings.map.fitBounds(markers.getBounds());
	// };

	SalesListings.toggleFeeOptions = function(event) {
		var isChecked = $('#sales .has-fee').prop('checked');
		if (isChecked) {
			$('#sales .show-op').addClass('hide');
			$('#sales .show-tp').removeClass('hide');
		} else {
			$('#sales .show-op').removeClass('hide');
			$('#sales .show-tp').addClass('hide');
		}
	};

	SalesListings.inheritFeeOptions = function() {
		bldg_id = $('#sales #sales_listing_unit_building_id').val();
		//console.log('got new ids', bldg_id);
		
		$.ajax({
			type: 'GET',
			url: '/sales_listings/fee_options/',
			data: {
				building_id: bldg_id,
			},
			//success: function(data) {},
			//error: function(data) {}
		});
	};

	SalesListings.setPositions = function() {
	  // loop through and give each task a data-pos
	  // attribute that holds its position in the DOM
	  $('#sales .img-thumbnail').each(function(i) {
	    $(this).attr("data-pos", i+1);
	  });
	};
	
	SalesListings.initialize = function() {
		document.addEventListener("page:restore", function() {
		  Listings.hideSpinner();
		});
		Listings.hideSpinner();
		$('#sales a').click(function() {
			Listings.showSpinner();
		});

		// main index table
		SalesListings.setupSortableColumns();		

		$('.close').click(function() {
			//console.log('detected click');
			Listings.hideSpinner();
		});

		$('#sales .has-fee').click(SalesListings.toggleFeeOptions);
		// when editing form
		SalesListings.toggleFeeOptions();
		// when creating a new listing, inherit TP/OP from building's landlord
		$('#sales #sales_listing_unit_building_id').change(SalesListings.inheritFeeOptions);

		// index filtering
		$('#sales input').keydown(SalesListings.preventEnter);
		$('#sales #address').bind('railsAutocomplete.select', SalesListings.throttledSearch);
	  $('#sales #address').change(SalesListings.throttledSearch);
	  $('#sales #unit').change(SalesListings.throttledSearch);
	  $('#sales #price_min').change(SalesListings.throttledSearch);
	  $('#sales #price_max').change(SalesListings.throttledSearch);
	  $('#sales #bed_min').change(SalesListings.throttledSearch);
	  $('#sales #bed_max').change(SalesListings.throttledSearch);
	  $('#sales #bath_min').change(SalesListings.throttledSearch);
	  $('#sales #bath_max').change(SalesListings.throttledSearch);
	  $('#sales #landlord').bind('railsAutocomplete.select', SalesListings.throttledSearch);
	  $('#sales #landlord').change(SalesListings.throttledSearch);
	  $('#sales #available_starting').blur(SalesListings.throttledSearch);
	  $('#sales #available_before').blur(SalesListings.throttledSearch);
	  $('#sales #pet_policy_shorthand').change(SalesListings.throttledSearch);
	  $('#sales #status').change(SalesListings.throttledSearch);
	  $('#sales #features').change(SalesListings.throttledSearch);
	  $('#sales #has_fee').change(SalesListings.throttledSearch);
	  $('#sales #neighborhood_ids').change(SalesListings.throttledSearch);
	  $('#sales #unit_feature_ids').change(SalesListings.throttledSearch);
	  $('#sales #building_feature_ids').change(SalesListings.throttledSearch);
	  // remove individual features by clicking on 'x' button
	  $('#sales .remove-unit-feature').click(SalesListings.removeUnitFeature);
	  $('#sales .remove-building-feature').click(SalesListings.removeBuildingFeature);
	  $('#sales .remove-neighborhood').click(SalesListings.removeNeighborhood);

	  // print pdf from the index page
	 //  $('#sales .btn-print-list').click( function(event) {
		//   Listings.showSpinner();
		//   $(this).toggleClass('active');
		// });

		var available_by = $('#sales .datepicker').attr('data-available-by');
		if (available_by) {
			$('#sales .datepicker').data("DateTimePicker").date(available_by);
		}

		// if ($('#big-map').length > 0) {
		// 	// mapbox
		// 	L.mapbox.accessToken = $('#mapbox-token').attr('data-mapbox-token');
	 //    // SalesListings.map = L.mapbox.map('big-map', 'rakelblujeans.8594241c', { zoomControl: false })
	    // 	.setView([40.6739591, -73.9570342], 13);

			// new L.Control.Zoom({ position: 'topright' }).addTo(SalesListings.map);
	  //   //map.removeLayer(marker)
	  //   //var markerLayer = L.mapbox.featureLayer().addTo(map);
	  //   SalesListings.overlays = L.layerGroup().addTo(SalesListings.map);
	  //   SalesListings.updateOverviewMap();
		//}

		// google map on show page
		var bldg_address = $('#map_canvas').attr('data-address') ? $('#map_canvas').attr('data-address') : 'New York, NY, USA';
		$("#sunit-panel").geocomplete({
	  	map: "#map_canvas",
	  	location: bldg_address,
	  	details: ".details"
	  }).bind("geocode:result", function(event, result){
	    //console.log(result);
	  }).bind("geocode:error", function(event, result){
	    //console.log("[ERROR]: " + result);
	  });

	  // for drag n dropping photos

		// disable auto discover
		Dropzone.autoDiscover = false;
	 	SalesListings.initializeImageDropzone();
    SalesListings.initializeDocumentsDropzone();
  };

})();

$(document).on('keyup',function(evt) {
  if (evt.keyCode == 27) {
  	Listings.hideSpinner();
  }
});

$(document).ready(SalesListings.initialize);