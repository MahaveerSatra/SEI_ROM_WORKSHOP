classdef RequiredProducts
    %RequiredProducts
    %
    % Class to set and store products required for a specific ROM method.
    %

    %   Copyright 2023 The MathWorks, Inc.

    properties(SetAccess = protected, GetAccess = public)
        Ver(1,:) string = string.empty;   %used for ver() check
        Product(1,:) string = string.empty; %used for license() check
        ErrorID string = string.empty
    end

    methods 
        function obj = RequiredProducts(ver,product,errorid)
            %RequiredProducts
            %
            %  obj = RequiredProducts(ver,products,[errorid])
            %
            %  Inputs:
            %    ver - string array of values to check with ver() and
            %          confirm product is available/installed
            %    products - string array of product license names, used to
            %               check with license() that the product is licensed
            %    errorid - optional string with message catalog ID of error
            %              message to throw if required products are not
            %              available
            %
            arguments
                ver(1,:) string = string.empty;
                product(1,:) string = string.empty;
                errorid string = string.empty;
            end

            obj.Ver = ver;
            obj.Product = product;
            obj.ErrorID = errorid;
        end

        function tf = haveProducts(this)
            %haveProducts
            %
            %   tf = haveProducts(obj)
            %
            %   Outputs:
            %     tf - true/false indicating that there are valid licenses
            %          for the required products and the products are installed

            tf = ~isempty(this.Ver(1)) && license('test', this.Product(1));
            if tf && numel(this.Ver) > 1
                for ct = 2:numel(this.Ver)
                    tf = tf && ...
                        ~isempty(this.Ver(ct)) && license('test', this.Product(ct));
                    if ~tf, break, end
                end
            end
        end
    end
end

% LocalWords:  errorid
