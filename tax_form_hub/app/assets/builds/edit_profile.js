(() => {
  // app/javascript/edit_profile.js
  if (window.location.pathname.includes("/profile/edit")) {
    $(document).ready(function() {
      $("#image-preview").on("click", function() {
        $("#profile_image_input").click();
      });
      $("#profile_image_input").on("change", function(e) {
        const file = e.target.files[0];
        if (file && file.type.startsWith("image/")) {
          const reader = new FileReader();
          reader.onload = function(e2) {
            $("#image-preview").attr("src", e2.target.result);
          };
          reader.readAsDataURL(file);
        }
      });
    });
  }
})();
