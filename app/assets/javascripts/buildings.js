$(document).ready(function(){
	// disable auto discover
	Dropzone.autoDiscover = false;
 
	// grap our upload form by its id
	$("#media-dropzone").dropzone({
		// restrict image size to a maximum 1MB
		//maxFilesize: 4,
		// changed the passed param to one accepted by
		// our rails app
		//paramName: "upload[image]",
		// show remove links on each image upload
		addRemoveLinks: true,
		// if the upload was successful
		success: function(file, response){
			// find the remove button link of the uploaded file and give it an id
			// based of the fileID response from the server
			$(file.previewTemplate).find('.dz-remove').attr('id', response.fileID);
			$(file.previewTemplate).find('.dz-remove').attr('bldg_id', response.bldgID);
			// add the dz-success class (the green tick sign)
			//console.log('/buildings/' + bldg_id + '/destroy_image/' + id);
			$(file.previewElement).addClass("dz-success");
		},
		//when the remove button is clicked
		removedfile: function(file){
			// grap the id of the uploaded file we set earlier
			var id = $(file.previewTemplate).find('.dz-remove').attr('id'); 
			var bldg_id = $(file.previewTemplate).find('.dz-remove').attr('bldg_id'); 
 			console.log('/buildings/' + bldg_id + '/destroy_image/' + id);
			// make a DELETE ajax request to delete the file
			$.ajax({
				type: 'DELETE',
				url: "/buildings/" + bldg_id + "/images/" + id,
				success: function(data){
					console.log(data.message);
					file.previewElement.remove();
				}
			});
		}

	});	
});