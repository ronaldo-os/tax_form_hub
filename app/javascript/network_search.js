import { hideSkeleton, setupSkeletonSafetyFallback } from './skeleton_loader';

function initNetworksPage() {
    if (window.location.pathname.includes('/networks')) {
        hideSkeleton('networks_skeleton', 'networks_content');
    }
}

document.addEventListener('turbo:load', initNetworksPage);
document.addEventListener('DOMContentLoaded', initNetworksPage);
initNetworksPage();

let timeout = null;

$(document).on('input', '#company_search_input', function () {
    const $searchForm = $('#network_search_form');

    if ($searchForm.length) {
        clearTimeout(timeout);

        timeout = setTimeout(function () {
            if ($searchForm[0].requestSubmit) {
                $searchForm[0].requestSubmit();
            } else {
                $searchForm.submit();
            }
        }, 50);
    }
});
