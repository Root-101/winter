* 0.0.6:
    * **DATE** :date: : 2024-10-26.
    * **Router** :twisted_rightwards_arrows: : Move `RouterConfig` inside `WinterRouter` (This way we can validate path
      and send response if it fails).
    * **Router** :twisted_rightwards_arrows: : `WinterRouter`: Check if route have a valid path before it's used (if
      path is NOT valid, it will not be used as a route and the function `RouterConfig.onInvalidUrl` will be called).
    * **Tests** :test_tube: : Add/Fix test for having `RouterConfig` inside `WinterRouter`.
    * **Router** :twisted_rightwards_arrows: : `MultiRouter`: Created a multi router class, It is a router that instead
      of containing a list of routes contains a list of other routers.
    * **Tests** :test_tube: : Add tests for `MultiRouter`.
    * **Docs** :scroll: : Fix details in general docs.

* 0.0.5:
    * **DATE** :date: : 2024-10-24.
    * **General** :hammer_and_wrench: : Fix example to pass in `pub points`

* 0.0.4:
    * **DATE** :date: : 2024-10-24.
    * **General** :hammer_and_wrench: : Fix code analyzer

* 0.0.3:
    * **DATE** :date: : 2024-10-24.
    * **General** :hammer_and_wrench: : Move code to `/lib` folder, update everything else.
    * **Docs** :scroll: : Add installing library to docs.

* 0.0.2:
    * **DATE** :date: : 2024-10-24.
    * **General** :hammer_and_wrench: : Clean up project, remove warnings, add example...

* 0.0.1:
    * **DATE** :date: : 2024-10-24.
    * **General** :hammer_and_wrench: : Initial version/deploy of lib.