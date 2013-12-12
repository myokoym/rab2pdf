jQuery(function($){
  $("#file").on("change", function(){
    if ($("#file").length) {
      $("#source").attr("disabled", "disabled");
    } else {
      $("#source").removeAttr("disabled");
    }
  });
});
