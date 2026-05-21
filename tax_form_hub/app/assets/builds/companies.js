(() => {
  // app/javascript/companies.js
  if (window.location.pathname.includes("/companies")) {
    $(document).ready(function() {
      function updateLabel(selectId, labelId, defaultText) {
        var $select = $(selectId);
        var $label = $(labelId);
        function setLabel() {
          var selectedText = $select.find("option:selected").text();
          if (selectedText) {
            $label.text(selectedText + " Number");
          } else {
            $label.text(defaultText);
          }
        }
        $select.on("change", setLabel);
        setLabel();
      }
      updateLabel("#company_id_type", "#company_id_number_label", "Company ID Number");
      updateLabel("#tax_id_type", "#tax_id_number_label", "Tax ID Number");
      $("#image-preview").on("click", function() {
        $("#profile_image_input").trigger('click');
      });
      $("#profile_image_input").on("change", function(e) {
        const file = e.target.files && e.target.files[0];
        if (!file) {
          return;
        }
        if (!file.type.startsWith("image/")) {
          alert("Please select a valid image file.");
          $("#image-preview").css('border', '2px solid red');
          e.target.value = "";
          return;
        }
        const reader = new FileReader();
        reader.onload = function(e2) {
          $("#image-preview").attr("src", e2.target.result);
        };
        reader.onerror = function() {
          alert("Failed to read the file. Please try another one.");
          e.target.value = "";
        };
        reader.readAsDataURL(file);
      });
    });
  }
})();
