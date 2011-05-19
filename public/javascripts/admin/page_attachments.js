function add_attachment() {
	var attachments_box = $('attachments');
	var template = new Template('<p class="attachment" id="file_#{id}"><label for="page_add_attachments_file_#{id}_file">Upload file: </label><input id="page_add_attachments_file_#{id}_file" type="file" name="page[add_attachments][file_#{id}][file]" /> <label>Type: </label><input type="radio" id="page_add_attachements_file_#{id}_screen_gallery_attachment_type_site_image" name="page[add_attachments][file_#{id}][screen_gallery_attachment_type]" value="site_image" checked="checked"><label for="page_add_attachements_file_#{id}_screen_gallery_attachment_type_site_image" class="radiobutton">Site Image</label><input type="radio" id="page_add_attachements_file_#{id}_screen_gallery_attachment_type_promo" name="page[add_attachments][file_#{id}][screen_gallery_attachment_type]" value="promotional_video"><label for="page_add_attachements_file_#{id}_screen_gallery_attachment_type_promo" class="radiobutton">Promotional Video</label><input type="radio" id="page_add_attachements_file_#{id}_screen_gallery_attachment_type_editorial" name="page[add_attachments][file_#{id}][screen_gallery_attachment_type]" value="editorial_content_showreel"><label for="page_add_attachements_file_#{id}_screen_gallery_attachment_type_editorial" class="radiobutton">Editorial Content Showreel</label><input type="radio" id="page_add_attachements_file_#{id}_screen_gallery_attachment_type_miscellaneous_document" name="page[add_attachments][file_#{id}][screen_gallery_attachment_type]" value="miscellaneous_document"><label for="page_add_attachements_file_#{id}_screen_gallery_attachment_type_miscellaneous_document" class="radiobutton">Miscellaneous Document</label><a href="#" onclick="Element.remove(\'file_#{id}\')">Cancel</a></p>');
	new Insertion.Bottom(attachments_box, template.evaluate({id: Math.round(Math.random() * 100000)}));
}
function remove_attachment(id){
	if(confirm("Really delete this attachment?")){
		var attachments_box = $('attachments');
		Element.remove("attachment_"+id);
		var template = new Template('<input type="hidden" name="page[delete_attachments][]" value="#{id}" />');
		new Insertion.Bottom(attachments_box, template.evaluate({id: id}));
		if(typeof $('attachments').down("#attachments-deleted") == 'undefined')
		{
			new Insertion.After('attachments-title', '<p class="attachment" id="attachments-deleted">Removed attachments will be deleted when you Save this page.</p>');
		}
	}
}