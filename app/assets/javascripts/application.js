// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or any plugin's vendor/assets/javascripts directory can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file.
//
// Read Sprockets README (https://github.com/rails/sprockets#sprockets-directives) for details
// about supported directives.
//
// these 2 must be first:
//= require jquery
//= require jquery_ujs
//= require bootsy
//= require jquery-ui
//= require html.sortable.min
// mapbox
//= require ckeditor/init
// leaflet.markercluster
//= require_tree .
//= require bootstrap-sprockets
//= require jquery.geocomplete.min
//= require autocomplete-rails
//= require dropzone
//= require local_time
//= require moment
//= require bootstrap-datetimepicker
//= require jquery.mousewheel.min
//= require selectize
//= require jquery.infinite-pages
//= require jquery.touchSwipe.min
//= require nested_form_fields
//= require clipboard
// must be last:
//= require turbolinks

Dropzone.autoDiscover = false;
document.addEventListener('turbolinks:load', Common.miscInits);

// debugging
$(window).unload(function() {
	Deals.clearTimer();
	Announcements.clearTimer();
  ResidentialListings.clearAnnouncementsTimer();
  ResidentialListings.clearTimer();
  CommercialListings.clearTimer();
  SalesListings.clearTimer();
});
