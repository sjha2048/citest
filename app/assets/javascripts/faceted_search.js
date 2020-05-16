jQuery(document).ready(function(){
    jQuery(document).on("exhibitConfigured.exhibit", function() {
        //need to show those facet list from beginning for exhibit to construct them, otherwise it can not
        //after that hide them here
        hide_specified_facet_list();
    });
});

//params items: e.g. Model_1,Model_2,...
function generateParamItems(resource_type, resource_ids){
    var items = resource_type + '_';
    items = items + resource_ids.replace(/,/g, ',' + resource_type + '_');
    return items;
}

function displayMoreLink(){
    $j(".more_link").show();
}

function hide_specified_facets(){
    $j(".specified_facets").hide();
}

function hide_specified_facet_list(){
    $j(".specified_facet_list").hide();
}

function show_specified_facets_for_active_tab(active_tab) {
    var more_facet_id = "specified_" + active_tab + "_facets";
    //(does not work with jquery)
    var more_facet_element = document.getElementById(more_facet_id);
    if (more_facet_element != null)
        more_facet_element.show();

    //display more-link for the first time
    var more_link = $('more_' + active_tab);
    var less_link = $('less_' + active_tab);

    if (more_link != null)
        if (more_link.offsetParent == null && less_link.offsetParent == null)
            more_link.show();
}
