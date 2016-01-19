'use strict';

angular.module('myApp.view1', ['ngRoute'])

.config(['$routeProvider', function($routeProvider) {
  $routeProvider.when('/view1', {
    templateUrl: 'view1/view1.html',
    controller: 'View1Ctrl'
  });
}])

.controller('View1Ctrl', ['$scope', function($scope) {
	$scope.query="";
	$scope.name="";
	$scope.dances="";

	$scope.events = [{'name' : "Hot bachata nights", 'dances' : ['Salsa', 'bachata']}, {"name": "Salsa Mondays"}];

	$scope.addEvent = function () {
		
		$scope.events.push({'name' : $scope.name, 'dances' : $scope.dances.split(' ')});
	};
}]);