with Lexer;           use Lexer;
with Locations;       use Locations;
with Nodes;           use Nodes;
with Nutils;          use Nutils;
with Parser.Errors;   use Parser.Errors;
with Types;           use Types;

package body Parser is

   Specification : Node_Id;

   --  Component categories

   type Component_Category is
     (
      CC_Data, CC_Subprogram, CC_Thread, CC_Threadgroup, CC_Process,
      CC_Memory, CC_Processor, CC_Bus, CC_Device, CC_System, CC_Unknown
     );

   Component_Category_To_Byte : constant array (Component_Category) of Byte :=
     (
      CC_Data        =>  1, CC_Subprogram  =>  2, CC_Thread      =>  3,
      CC_Threadgroup =>  4, CC_Process     =>  5, CC_Memory      =>  6,
      CC_Processor   =>  7, CC_Bus         =>  8, CC_Device      =>  9,
      CC_System      => 10, CC_Unknown     =>  0
     );

   type P_Item_Function_Ptr is access function return Node_Id;
   --  Pointer to a function which parse an item

   procedure Add_Package_Items (S : Node_Id; D : Node_Id);
   --  Add all package items of S into D (i.e. all items and properties)
   --  S and D are K_Package_Items type

   function P_AADL_Declaration return Node_Id;
   function P_AADL_Specification return Node_Id;

   function P_Annex_Specification return Node_Id;
   function P_Annex_Subclause return Node_Id;

   function P_Classifier_Reference return Node_Id;

   function P_Component return Node_Id;
   --  Parse Component_Type, Component_Type_Extension
   --        Component_Implementation, Component_Implementation_Extension

   function P_Component_Category return Component_Category;
   --  Parse Component_Category, current token is the first token of
   --  Component_Category

   function P_Component_Implementation (Start_Loc : Location;
                                        Category  : Component_Category)
                                       return Node_Id;
   --  Parse Component_Implementation, Component_Implementation_Extension

   function P_Component_Implementation_Name return Node_Id;

   function P_Component_Type (Start_Loc : Location;
                              Category  : Component_Category) return Node_Id;
   --  Parse Component_Type, Component_Type_Extension

   function P_Component_Type (Start_Loc  : Location;
                              Category   : Component_Category;
                              Identifier : Node_Id) return Node_Id;
   --  Parse Component_Type

   function P_Component_Type_Extension (Start_Loc  : Location;
                                        Category   : Component_Category;
                                        Identifier : Node_Id) return Node_Id;
   --  Parse Component_Type_Extension

   function P_Expected_Identifier (Expected_Name : Name_Id) return Boolean;
   --  Parse Identifier
   --  Return TRUE if parsed identifier name equals to Expected_Name

   function P_Expected_Identifiers (Identifiers : List_Id;
                                    Delimiter   : Token_Type) return Boolean;
   --  Parse { Identifier Delimiter } * Identifier
   --  These parsed identifiers must be the same as in list L
   --  These parsed identifiers will NOT be added in list L
   --  This function is useful for parsing 'end' clause for example
   --  Return TRUE if everything is OK

   function P_Feature return Node_Id;

   function P_Identifiers (Delimiter : Token_Type) return List_Id;
   --  Parse { Identifier Delimiter } * Identifier

   function P_Items_List (Func : P_Item_Function_Ptr;
                          Code : Parsing_Code) return List_Id;
   --  Parse list items of syntax: ( { Item } + | none_statement )
   --  Func is a pointer which is used to parse (Item)
   --  Code indicates the object that we are parsing

   function P_Items_List (Func      : P_Item_Function_Ptr;
                          Delimiter : Token_Type) return List_Id;
   --  Parse list items of syntax: ( { Item } + Delimiter )

   function P_None_Statement return Boolean;
   --  Parse " none ; ", this function does NOT return a Node_Id because
   --  no useful data will be retrieved
   --  Return TRUE if the reserved word 'none' is followed by a ';'

   function P_Package_Items return Node_Id;
   function P_Package_Specification return Node_Id;
   function P_Parameter return Node_Id;

   function P_Port_Group (Start_Loc : Location) return Node_Id;

   function P_Port_Spec (Start_Loc        : Location;
                         Identifiers_List : List_Id;
                         Is_Refinement    : Boolean) return Node_Id;
   --  Current token must be reserved words 'in' or 'out'
   --  If Is_Refinement = TRUE, parse a Port_Refinement

   function P_Port_Type return Node_Id;
   --  Parse Port_Type, the current token is the first token of Port_Type

   function P_Property_Association return Node_Id;
   function P_Property_Set (Start_Loc : Location) return Node_Id;
   function P_Subcomponent_Access return Node_Id;
   function P_System_Instance return Node_Id;

   function P_Unique_Component_Type_Name return Node_Id;
   --  Current token must be an identifier


   -----------------------
   -- Add_Package_Items --
   -----------------------

   procedure Add_Package_Items (S : Node_Id; D : Node_Id) is
      LD : List_Id;
      LS : List_Id;

   begin
      LD := Items (D);
      LS := Items (S);

      if Present (LS) then
         if Present (LD) then
            Append_Node_To_List (First_Node (LS), LD);
         else
            Set_Items (D, LS);
         end if;
      end if;

      LD := Properties (D);
      LS := Properties (S);

      if Present (LS) then
         if Present (LD) then
            Append_Node_To_List (First_Node (LS), LD);
         else
            Set_Properties (D, LS);
         end if;
      end if;
   end Add_Package_Items;

   ------------------------
   -- P_AADL_Declaration --
   ------------------------

   --  AADL_declaration ::= component_classifier | package_spec |
   --                       port_group_type | port_group_type_extension |
   --                       system_instance | property_set

   --  component_classifier          begins with 'component'
   --  package_spec                  begins with 'package'
   --  port_group_type               begins with 'port type'
   --  port_group_type_extension     begins with 'port type'
   --  system_instance               begins with an identifier
   --  property_set                  begins with 'property set'

   function P_AADL_Declaration return Node_Id is
      Loc : Location;

   begin
      Scan_Token;

      case Token is
         when T_Data | T_Subprogram | T_Thread | T_Process
           | T_Memory | T_Processor | T_Bus | T_Device
           | T_System =>
            return P_Component;

         when T_Package =>
            return P_Package_Specification;

         when T_Port =>
            Save_Lexer (Loc);
            Scan_Token;
            if Token = T_Group then
               return P_Port_Group (Loc);
            else
               DPE (PC_Port_Group, T_Group);
               Skip_Tokens (T_Semicolon);
               return No_Node;
            end if;

         when T_Property =>
            Save_Lexer (Loc);
            Scan_Token;
            if Token = T_Set then
               return P_Property_Set (Loc);
            else
               DPE (PC_Property_Set, T_Set);
               Skip_Tokens (T_Semicolon);
               return No_Node;
            end if;

         when T_Identifier =>
            return P_System_Instance;

         when others =>
            DPE (PC_AADL_Declaration);
            Skip_Tokens (T_Semicolon);
            return No_Node;
      end case;
   end P_AADL_Declaration;

   --------------------------
   -- P_AADL_Specification --
   --------------------------

   --  AADL_specification ::= { AADL_declaration } +

   function P_AADL_Specification return Node_Id is
      Declarations    : List_Id;
      Declaration     : Node_Id;

   begin
      Specification := New_Node (K_AADL_Specification, Token_Location);
      Declarations  := New_List (K_AADL_Declaration_List, Token_Location);

      loop
         exit when End_Of_File;
         Declaration := P_AADL_Declaration;
         if Present (Declaration) then
            Append_Node_To_List (Declaration, Declarations);
         end if;
      end loop;

      Set_Declarations (Specification, Declarations);

      return Specification;
   end P_AADL_Specification;

   ---------------------------
   -- P_Annex_Specification --
   ---------------------------

   function P_Annex_Specification return Node_Id is
      Annex : Node_Id;

   begin
      --  TODO
      Annex := New_Node (K_Node_Id, Token_Location);
      return Annex;
   end P_Annex_Specification;

   -----------------------
   -- P_Annex_Subclause --
   -----------------------

   function P_Annex_Subclause return Node_Id is
      Annex : Node_Id;

   begin
      --  TODO
      Annex := New_Node (K_Node_Id, Token_Location);
      return Annex;
   end P_Annex_Subclause;

   ----------------------------
   -- P_Classifier_Reference --
   ----------------------------

   --  classifier_reference ::=
   --      unique_component_type_name [ . component_implementation_name ]

   function P_Classifier_Reference return Node_Id is
      Class_Ref      : Node_Id;
      Comp_Type_Name : Node_Id;
      Comp_Impl_Name : Node_Id;
      Loc            : Location;

   begin
      Comp_Type_Name := P_Unique_Component_Type_Name;
      if not Present (Comp_Type_Name) then
         DPE (PC_Classifier_Reference);
         return No_Node;
      end if;

      Class_Ref := New_Node (K_Classifier_Ref, Nodes.Loc (Comp_Type_Name));
      Set_Component_Type_Name (Class_Ref, Comp_Type_Name);

      --  Parse [ . Component_Implementation_Name]

      Save_Lexer (Loc);
      Scan_Token;
      if Token = T_Dot then
         Comp_Impl_Name := P_Component_Implementation_Name;
         if not Present (Comp_Impl_Name) then
            return No_Node;
         end if;

         Set_Component_Impl_Name (Class_Ref, Comp_Impl_Name);
      else
         Restore_Lexer (Loc);
         Set_Component_Impl_Name (Class_Ref, No_Node);
      end if;

      return Class_Ref;
   end P_Classifier_Reference;

   -----------------
   -- P_Component --
   -----------------

   function P_Component return Node_Id is
      Category  : Component_Category;
      Loc       : Location;
      Start_Loc : Location;

   begin
      Start_Loc := Token_Location;
      Category  := P_Component_Category;
      Save_Lexer (Loc);
      Scan_Token;
      if Token = T_Implementation then
         return P_Component_Implementation (Start_Loc, Category);
      else
         Restore_Lexer (Loc);
         return P_Component_Type (Start_Loc, Category);
      end if;
   end P_Component;

   --------------------------
   -- P_Component_Category --
   --------------------------

   --  component_category ::= software_category | platform_category
   --                                    | composite_category
   --  software_category  ::= data | subprogram | thread | thread group
   --                                    | process
   --  platform_category  ::= memory | processor | bus | device
   --  composite_category ::= system

   function P_Component_Category return Component_Category is
      Loc : Location;

   begin
      case Token is
         when T_Data =>
            return CC_Data;

         when T_Subprogram =>
            return CC_Subprogram;

         when T_Thread =>
            Save_Lexer (Loc);
            Scan_Token;
            if Token = T_Group then
               return CC_Threadgroup;
            else
               Restore_Lexer (Loc);
               return CC_Thread;
            end if;

         when T_Process =>
            return CC_Process;

         when T_Memory =>
            return CC_Memory;

         when T_Processor =>
            return CC_Processor;

         when T_Bus =>
            return CC_Bus;

         when T_Device =>
            return CC_Device;

         when T_System =>
            return CC_System;

         when others =>
            DPE (PC_Component_Category);
            return CC_Unknown;
      end case;
   end P_Component_Category;

   --------------------------------
   -- P_Component_Implementation --
   --------------------------------

   function P_Component_Implementation (Start_Loc : Location;
                                        Category  : Component_Category)
                                       return Node_Id is
      Impl : Node_Id;    --  output

   begin
      --  TODO

      Impl := New_Node (K_Component_Implementation, Start_Loc);
      Set_Category (Impl, Component_Category_To_Byte (Category));
      return Impl;
   end P_Component_Implementation;

   -------------------------------------
   -- P_Component_Implementation_Name --
   -------------------------------------

   function P_Component_Implementation_Name return Node_Id is
      Impl_Name : Node_Id;
      Loc       : Location;

   begin
      Save_Lexer (Loc);
      Scan_Token;
      Impl_Name := New_Node (K_Component_Impl_Name, Token_Location);

      if Token = T_Others then
         Set_Identifier (Impl_Name, No_Node);
         Set_Is_Binding (Impl_Name, False);

      elsif Token = T_Binding then
         Set_Identifier (Impl_Name, No_Node);
         Set_Is_Binding (Impl_Name, True);

      elsif Token = T_Identifier then
         Set_Identifier (Impl_Name, Make_Current_Identifier);

      else
         DPE (PC_Component_Implementation_Name);
         Restore_Lexer (Loc);
         return No_Node;
      end if;

      return Impl_Name;
   end P_Component_Implementation_Name;

   ----------------------
   -- P_Component_Type --
   ----------------------

   function P_Component_Type (Start_Loc : Location;
                              Category  : Component_Category) return Node_Id is
      Ident : Node_Id;     --  component identifier
      Loc   : Location;

   begin
      Save_Lexer (Loc);
      Scan_Token;
      if Token = T_Identifier then
         Ident := Make_Current_Identifier;
         Save_Lexer (Loc);
         Scan_Token;

         if Token = T_Extends then
            return P_Component_Type_Extension (Start_Loc, Category, Ident);
         else
            Restore_Lexer (Loc);
            return P_Component_Type (Start_Loc, Category, Ident);
         end if;

      else
         DPE (PC_Component_Type, T_Identifier);
         Skip_Tokens ((T_End, T_Semicolon));
         return No_Node;
      end if;
   end P_Component_Type;

   ----------------------
   -- P_Component_Type --
   ----------------------

   --  component_type ::=
   --     component_category defining_component_type_identifier
   --     [ provides ( { feature } + | none_statement ) ]
   --     [ requires ( { required_subcomponent_access } + | none_statement ) ]
   --     [ parameters ( { parameter } + | none_statement ) ]
   --     [ properties ( { component_type_property_association } +
   --                    | none_statement ) ]
   --     { annex_subclause } *
   --  end defining_component_type_identifier ;

   function P_Component_Type (Start_Loc  : Location;
                              Category   : Component_Category;
                              Identifier : Node_Id) return Node_Id is
      Component       : Node_Id;
      Loc             : Location;
      Provides        : List_Id := No_List;
      Requires        : List_Id := No_List;
      Parameters      : List_Id := No_List;
      Properties      : List_Id := No_List;
      Annexes         : List_Id := No_List;
      Current_Element : List_Id;
      Current_Annex   : Node_Id;

   begin
      Component := New_Node (K_Component_Type, Start_Loc);

      loop
         Scan_Token;
         case Token is
            when T_Provides =>
               Current_Element := P_Items_List (P_Feature'Access, PC_Provides);
               if Present (Current_Element) then
                  Append_List_To_List (Current_Element, Provides);
               else
                  Skip_Tokens ((T_End, T_Semicolon));
                  return No_Node;
               end if;

            when T_Requires =>
               Current_Element := P_Items_List (P_Subcomponent_Access'Access,
                                                PC_Requires);
               if Present (Current_Element) then
                  Append_List_To_List (Current_Element, Requires);
               else
                  Skip_Tokens ((T_End, T_Semicolon));
                  return No_Node;
               end if;

            when T_Parameters =>
               Current_Element := P_Items_List (P_Parameter'Access,
                                                PC_Parameters);
               if Present (Current_Element) then
                  Append_List_To_List (Current_Element, Parameters);
               else
                  Skip_Tokens ((T_End, T_Semicolon));
                  return No_Node;
               end if;

            when T_Properties =>
               Current_Element := P_Items_List (P_Property_Association'Access,
                                                PC_Properties);
               if Present (Current_Element) then
                  Append_List_To_List (Current_Element, Properties);
               else
                  Skip_Tokens ((T_End, T_Semicolon));
                  return No_Node;
               end if;

            when T_Annex =>
               Save_Lexer (Loc);
               Current_Annex := P_Annex_Subclause;
               if Present (Current_Annex) then
                  if not Present (Annexes) then
                     Annexes := New_List (K_List_Id, Loc);
                  end if;
                  Append_Node_To_List (Current_Annex, Annexes);
               else
                  Skip_Tokens ((T_End, T_Semicolon));
                  return No_Node;
               end if;

            when T_End =>
               exit;

            when others =>
               DPE (PC_Component_Type);
               Skip_Tokens ((T_End, T_Semicolon));
               return No_Node;
         end case;
      end loop;

      if P_Expected_Identifier (Name (Identifier)) then
         Save_Lexer (Loc);
         Scan_Token;

         if Token = T_Semicolon then
            Set_Identifier (Component, Identifier);
            Set_Category (Component, Component_Category_To_Byte (Category));
            Set_Provides (Component, Provides);
            Set_Requires (Component, Requires);
            Set_Parameters (Component, Parameters);
            Set_Properties (Component, Properties);
            Set_Annexes (Component, Annexes);
            Set_Parent (Component, No_Node);

            return Component;
         else
            DPE (PC_Component_Type, T_Semicolon);
            Restore_Lexer (Loc);
            return No_Node;
         end if;
      else
         --  Error when parsing Defining_Identifier, quit
         Skip_Tokens (T_Semicolon);
         return No_Node;
      end if;
   end P_Component_Type;

   --------------------------------
   -- P_Component_Type_Extension --
   --------------------------------

   --  component_type_extension ::=
   --     component_category defining_component_type_identifier
   --     extends unique_component_type_identifier
   --     [ provides ( { feature | feature_refinement } + | none_statement ) ]
   --     [ requires ( { required_subcomponent_access
   --                  | required_subcomponent_access_refinement } +
   --                | none_statement ) ]
   --     [ parameters ( { parameter | parameter_refinement } +
   --                | none_statement ) ]
   --     [ properties ( { component_type_property_association } +
   --               | none_statement ) ]
   --     { annex_subclause } *
   --  end defining_component_type_identifier ;

   function P_Component_Type_Extension (Start_Loc  : Location;
                                        Category   : Component_Category;
                                        Identifier : Node_Id) return Node_Id is
      Component : Node_Id;

   begin
      Component := New_Node (K_Component_Type, Start_Loc);

      --  TODO

      Set_Category (Component, Component_Category_To_Byte (Category));
      Set_Identifier (Component, Identifier);
      return Component;
   end P_Component_Type_Extension;

   ---------------------------
   -- P_Expected_Identifier --
   ---------------------------

   function P_Expected_Identifier (Expected_Name : Name_Id) return Boolean is
      Loc : Location;

   begin
      Save_Lexer (Loc);
      Scan_Token;
      if Token = T_Identifier
        and then Token_Name = Expected_Name then
         return True;
      else
         DPE (PC_Defining_Identifier, Expected_Name);
         Restore_Lexer (Loc);
         return False;
      end if;
   end P_Expected_Identifier;

   ----------------------------
   -- P_Expected_Identifiers --
   ----------------------------

   function P_Expected_Identifiers (Identifiers : List_Id;
                                    Delimiter : Token_Type) return Boolean is
      Identifier   : Node_Id;   --  Current identifier in list of identifiers
      Current_Name : Name_Id;   --  Name of current identifier
      Loc          : Location;

   begin
      if Is_Empty (Identifiers) then
         return True;
      end if;

      Identifier := First_Node (Identifiers);

      while Present (Identifier) loop
         Current_Name := Name (Identifier);
         Save_Lexer (Loc);
         Scan_Token;

         if Token = T_Identifier then
            if Token_Name /= Current_Name then
               DPE (PC_Defining_Name, Current_Name);
               Restore_Lexer (Loc);
               return False;
            end if;
         else
            DPE (PC_Defining_Name, Current_Name);
            Restore_Lexer (Loc);
            return False;
         end if;

         Identifier := Next_Node (Identifier);

         if Present (Identifier) then
            --  Parse delimiter
            Save_Lexer (Loc);
            Scan_Token;

            if Token /= Delimiter then
               DPE (PC_Defining_Name, Delimiter);
               Restore_Lexer (Loc);
               return False;
            end if;
         end if;
      end loop;

      return True;
   end P_Expected_Identifiers;

   ---------------
   -- P_Feature --
   ---------------

   --  feature ::= port_spec | port_group_spec
   --              | clientserver_subprogram | data_subprogram_spec
   --              | provided_data_or_bus_subcomponent_access

   --  feature_refinement ::= port_refinement | port_group_refinement
   --                         | clientserver_subprogram_refinement
   --                         | data_subprogram_refinement
   --                   | provided_data_or_bus_subcomponent_access_refinement

   function P_Feature return Node_Id is
      Identifiers_List : List_Id;
      Start_Loc        : Location;

   begin
      Identifiers_List := P_Identifiers (T_Comma);
      if Present (Identifiers_List) then
         Start_Loc := Nodes.Loc (First_Node (Identifiers_List));
         --  the location of current feature is the location of the first
         --  identifier of Identifiers_List

         Scan_Token;

         if Token = T_Colon then
            Scan_Token;

            case Token is
               when T_In | T_Out =>
                  return P_Port_Spec (Start_Loc, Identifiers_List, False);

               when others =>
                  DPE (PC_Feature);
                  Skip_Tokens (T_Semicolon);
                  return No_Node;
            end case;

         else
            DPE (PC_Feature, T_Colon);
            Skip_Tokens (T_Semicolon);
            return No_Node;
         end if;
      else
         --  Error when parsing identifiers list, quit
         return No_Node;
      end if;
   end P_Feature;

   -------------------
   -- P_Identifiers --
   -------------------

   function P_Identifiers (Delimiter : Token_Type) return List_Id is
      Identifier  : Node_Id;
      Identifiers : List_Id;
      Loc         : Location;

   begin
      Save_Lexer (Loc);
      Scan_Token;
      if Token /= T_Identifier then
         Restore_Lexer (Loc);
         return No_List;
      end if;

      Identifiers := New_List (K_Identifiers_List, Token_Location);

      loop
         Identifier := Make_Current_Identifier;
         Append_Node_To_List (Identifier, Identifiers);

         Save_Lexer (Loc);
         Scan_Token;
         if Token /= Delimiter then
            Restore_Lexer (Loc);
            return Identifiers;
         end if;

         Scan_Token;
         if Token /= T_Identifier then
            Restore_Lexer (Loc);
            return Identifiers;
         end if;
      end loop;
   end P_Identifiers;

   ------------------
   -- P_Items_List --
   ------------------

   --  ( { Item } + | none_statement )

   function P_Items_List (Func : P_Item_Function_Ptr;
                          Code : Parsing_Code) return List_Id is
      Loc   : Location;
      Items : List_Id;
      Item  : Node_Id;

   begin
      Items := New_List (K_List_Id, Token_Location);
      Save_Lexer (Loc);
      Scan_Token;
      if Token = T_None then
         if not P_None_Statement then
            return No_List;
         end if;

      else
         Restore_Lexer (Loc);
         loop
            Save_Lexer (Loc);
            Item := Func.all;
            if Present (Item) then
               Append_Node_To_List (Item, Items);
            else
               --  Error when parsing item, restore lexer
               Restore_Lexer (Loc);
               if Is_Empty (Items) then
                  --  list must contain at least one element, { Item } +
                  DPE (Code, "list is empty");
               end if;
               exit;
            end if;
         end loop;
      end if;

      return Items;
   end P_Items_List;

   ------------------
   -- P_Items_List --
   ------------------

   --  ( { Item } + Delimiter )

   function P_Items_List (Func      : P_Item_Function_Ptr;
                          Delimiter : Token_Type) return List_Id is
      Loc   : Location;
      Items : List_Id;
      Item  : Node_Id;

   begin
      Items := New_List (K_List_Id, Token_Location);
      loop
         Item := Func.all;
         if Present (Item) then
            Append_Node_To_List (Item, Items);
         else
            --  Error when parsing item, ignores tokens ---> Delimiter; quit
            Skip_Tokens (Delimiter);
            return No_List;
         end if;

         Save_Lexer (Loc);
         Scan_Token;
         if Token = Delimiter then
            return Items;
         else
            Restore_Lexer (Loc);
         end if;
      end loop;
   end P_Items_List;

   ----------------------
   -- P_None_Statement --
   ----------------------

   --  none_statement ::= none ;

   function P_None_Statement return Boolean is
      Loc : Location;

   begin
      Save_Lexer (Loc);
      Scan_Token;
      if Token = T_Semicolon then
         return True;
      else
         DPE (PC_None_Statement, T_Semicolon);
         Restore_Lexer (Loc);
         return False;
      end if;
   end P_None_Statement;

   ---------------------
   -- P_Package_Items --
   ---------------------

   --  package_items ::=
   --   { component_type | component_type_extension |
   --     component_implementation | component_implementation_extension |
   --     port_group_type | port_group_type_extension |
   --     annex_specification } +
   --   [ properties
   --     ( property_association { property_association } | none_statement ) ]

   function P_Package_Items return Node_Id is
      Package_Items : Node_Id;
      Items         : List_Id := No_List;
      Properties    : List_Id := No_List;
      Item          : Node_Id;
      Loc           : Location;

   begin
      Package_Items := New_Node (K_Package_Items, Token_Location);

      --  Parse items

      Items := New_List (K_List_Id, Token_Location);
      loop
         Save_Lexer (Loc);
         Scan_Token;
         case Token is
            when T_Data | T_Subprogram | T_Thread | T_Process
              | T_Memory | T_Processor | T_Bus | T_Device
              | T_System =>
               Item := P_Component;

            when T_Port =>
               Save_Lexer (Loc);
               Scan_Token;
               if Token = T_Group then
                  Item := P_Port_Group (Loc);
               else
                  DPE (PC_Port_Group, T_Group);
                  Skip_Tokens (T_Semicolon);
                  return No_Node;
               end if;

            when T_Annex =>
               Item := P_Annex_Specification;

            when others =>
               Restore_Lexer (Loc);
               exit;
         end case;

         if Present (Item) then
            Append_Node_To_List (Item, Items);
         else
            return No_Node;
         end if;
      end loop;

      --  Parse properties

      Save_Lexer (Loc);
      Scan_Token;

      if Token = T_Properties then
         Properties := P_Items_List (P_Property_Association'Access,
                                     PC_Properties);
         if not Present (Properties) then
            --  Error when parsing properties, quit
            return No_Node;
         end if;
      else
         --  No property declared
         Restore_Lexer (Loc);
      end if;

      --  Return result

      Set_Items (Package_Items, Items);
      Set_Properties (Package_Items, Properties);

      return Package_Items;
   end P_Package_Items;

   -----------------------------
   -- P_Package_Specification --
   -----------------------------

   --  package_spec ::=
   --     package defining_package_name
   --      ( public package_items [ private package_items ]
   --         | private package_items )
   --     end defining_package_name;

   --  package_name ::= { package_identifier . } * package_identifier

   function P_Package_Specification return Node_Id is
      Package_Spec   : Node_Id;      --  result
      Defining_Name  : List_Id;      --  package name
      Current_Items  : Node_Id;      --  items parsed by P_Package_Items
      Public_Items   : Node_Id;      --  all public items of the package
      Private_Items  : Node_Id;      --  all private items of the package
      Loc            : Location;

   begin
      Package_Spec  := New_Node (K_Package_Spec, Token_Location);
      Public_Items  := No_Node;
      Private_Items := No_Node;

      Defining_Name := P_Identifiers (T_Dot);
      if not Present (Defining_Name) then
         --  Defining_Package_Name is not parsed correctly, quit
         DPE (PC_Defining_Name);
         Skip_Tokens ((T_End, T_Semicolon));
         return No_Node;
      end if;

      loop
         Set_Kind (Node_Id (Defining_Name), K_Package_Name);
         Save_Lexer (Loc);
         Scan_Token;
         if Token = T_Public then
            Current_Items := P_Package_Items;
            if Present (Current_Items) then
               if Present (Public_Items) then
                  Add_Package_Items (Current_Items, Public_Items);
               else
                  Public_Items := Current_Items;
               end if;
            else
               Skip_Tokens ((T_End, T_Semicolon));
               return No_Node;
            end if;

         elsif Token = T_Private then
            Current_Items := P_Package_Items;
            if Present (Current_Items) then
               if Present (Private_Items) then
                  Add_Package_Items (Current_Items, Private_Items);
               else
                  Private_Items := Current_Items;
               end if;
            else
               Skip_Tokens ((T_End, T_Semicolon));
               return No_Node;
            end if;

         elsif Token = T_End then
            exit;

         else
            DPE (PC_Package_Specification);
            Skip_Tokens ((T_End, T_Semicolon));
            return No_Node;
         end if;
      end loop;

      if P_Expected_Identifiers (Defining_Name, T_Dot) then
         Save_Lexer (Loc);
         Scan_Token;

         if Token = T_Semicolon then
            Set_Package_Name (Package_Spec, Defining_Name);
            Set_Public_Package_Items (Package_Spec, Public_Items);
            Set_Private_Package_Items (Package_Spec, Private_Items);

            return Package_Spec;
         else
            DPE (PC_Package_Specification, T_Semicolon);
            Restore_Lexer (Loc);
            return No_Node;
         end if;
      else
         --  Error when parsing Defining_Name, quit
         Skip_Tokens (T_Semicolon);
         return No_Node;
      end if;
   end P_Package_Specification;

   -----------------
   -- P_Parameter --
   -----------------

   function P_Parameter return Node_Id is
   begin
      return No_Node;
   end P_Parameter;

   ------------------
   -- P_Port_Group --
   ------------------

   function P_Port_Group (Start_Loc : Location) return Node_Id is
      Port_Group : Node_Id;

   begin
      --  TODO
      Port_Group := New_Node (K_Node_Id, Start_Loc);
      return Port_Group;
   end P_Port_Group;

   -----------------
   -- P_Port_Spec --
   -----------------

   --  port_spec ::=
   --     defining_port_identifier_list : ( in | out | in out ) port_type
   --        [ { { port_property_association } + } ] ;

   --  port_refinement ::=
   --     defining_port_identifier_list : refined to
   --        ( in | out | in out ) port_type
   --        [ { { port_property_association } + } ] ;

   function P_Port_Spec (Start_Loc        : Location;
                         Identifiers_List : List_Id;
                         Is_Refinement    : Boolean) return Node_Id is
      Is_In     : Boolean := False;
      Is_Out    : Boolean := False;
      Port_Spec : Node_Id;
      Port_Type : Node_Id;
      Port_Prop : List_Id := No_List;  --  list of Port_Property_Association

   begin
      if Token = T_In then
         Is_In := True;
         Scan_Token;
         if Token = T_Out then
            Is_Out := True;
            Scan_Token;
         end if;
      else
         Is_Out := True;
         Scan_Token;
         if Token = T_In then
            Is_In := True;
            Scan_Token;
         end if;
      end if;

      Port_Type := P_Port_Type;

      if Present (Port_Type) then
         Scan_Token;
         if Token = T_Left_Curly_Bracket then
            Port_Prop := P_Items_List (P_Property_Association'Access,
                                       T_Right_Curly_Bracket);
            if not Present (Port_Prop) then
               --  Error when parsing list of Port_Property_Association, quit
               Skip_Tokens (T_Semicolon);
               return No_Node;
            else
               Scan_Token;  --  Parse expected ';'
            end if;
         end if;

         if Token = T_Semicolon then
            Port_Spec := New_Node (K_Port_Spec, Start_Loc);
            Set_Is_Refinement (Port_Spec, Is_Refinement);
            Set_Identifiers_List (Port_Spec, Identifiers_List);
            Set_Is_In (Port_Spec, Is_In);
            Set_Is_Out (Port_Spec, Is_Out);
            Set_Port_Type (Port_Spec, Port_Type);
            Set_Properties (Port_Spec, Port_Prop);

            return Port_Spec;
         else
            DPE (PC_Port_Spec, T_Semicolon);
            return No_Node;
         end if;
      else
         --  Error when parsing Port_Type, quit
         Skip_Tokens (T_Semicolon);
         return No_Node;
      end if;
   end P_Port_Spec;

   -----------------
   -- P_Port_Type --
   -----------------

   --  port_type ::= ( data port data_classifier_reference  )
   --              | ( event data port data_classifier_reference )
   --              | ( event port )

   function P_Port_Type return Node_Id is
      Port_Type : Node_Id;
      Is_Data   : Boolean := False;
      Is_Event  : Boolean := False;
      Class_Ref : Node_Id;

   begin
      Port_Type := New_Node (K_Port_Type, Token_Location);

      if Token = T_Event then
         Is_Event := True;
         Scan_Token;
         if Token = T_Data then
            Is_Data := True;
            Scan_Token;
         end if;
      elsif Token = T_Data then
         Is_Data := True;
         Scan_Token;
      else
         DPE (PC_Port_Type);
         return No_Node;
      end if;

      if Token /= T_Port then
         DPE (PC_Port_Type, T_Port);
         return No_Node;
      end if;

      if Is_Data then
         Class_Ref := P_Classifier_Reference;
         if Present (Class_Ref) then
            Set_Is_Event (Port_Type, Is_Event);
            Set_Data_Ref (Port_Type, Class_Ref);
         else
            --  Error when parsing Classifier_Reference, quit
            return No_Node;
         end if;
      else
         Set_Is_Event (Port_Type, Is_Event);
         Set_Data_Ref (Port_Type, No_Node);
      end if;

      return Port_Type;
   end P_Port_Type;

   ----------------------------
   -- P_Property_Association --
   ----------------------------

   function P_Property_Association return Node_Id is
   begin
      return No_Node;
   end P_Property_Association;

   --------------------
   -- P_Property_Set --
   --------------------

   function P_Property_Set (Start_Loc : Location) return Node_Id is
      Property_Set : Node_Id;

   begin
      --  TODO
      Property_Set := New_Node (K_Node_Id, Start_Loc);
      return Property_Set;
   end P_Property_Set;

   ---------------------------
   -- P_Subcomponent_Access --
   ---------------------------

   function P_Subcomponent_Access return Node_Id is
   begin
      return No_Node;
   end P_Subcomponent_Access;

   -----------------------
   -- P_System_Instance --
   -----------------------

   function P_System_Instance return Node_Id is
      System_Instance : Node_Id;
      --  First identifier is in CURRENT TOKEN

   begin
      --  TODO
      System_Instance := New_Node (K_Node_Id, Token_Location);
      return System_Instance;
   end P_System_Instance;

   ----------------------------------
   -- P_Unique_Component_Type_Name --
   ----------------------------------

   function P_Unique_Component_Type_Name return Node_Id is
      Unique_Name  : Node_Id;
      Package_Name : List_Id;
      Loc          : Location;

   begin
      Package_Name := P_Identifiers (T_Dot);

      if not Present (Package_Name) then
         DPE (PC_Unique_Component_Type_Name);
         return No_Node;

      else
         Set_Kind (Node_Id (Package_Name), K_Package_Name);
         Unique_Name := New_Node (K_Unique_Component_Type_Name,
                                  Nodes.Loc (First_Node (Package_Name)));
         Save_Lexer (Loc);
         Scan_Token;
         if Token = T_Colon_Colon then
            --  Package_Name is parsed
            Save_Lexer (Loc);
            Scan_Token;

            if Token /= T_Identifier then
               DPE (PC_Unique_Component_Type_Name, T_Identifier);
               Restore_Lexer (Loc);
               return No_Node;
            end if;

            Set_Package_Name (Unique_Name, Package_Name);
            Set_Identifier (Unique_Name, Make_Current_Identifier);
            return Unique_Name;

         else
            --  No Package_Name. The first element of parsed identifiers list
            --  is Component_Type_Identifier.
            --  Restore lexer to the location of the first element of this list

            Restore_Lexer (Nodes.Loc (First_Node (Package_Name)));

            Set_Package_Name (Unique_Name, No_List);
            Set_Identifier (Unique_Name, First_Node (Package_Name));
            return Unique_Name;
         end if;
      end if;
   end P_Unique_Component_Type_Name;

   -------------
   -- Process --
   -------------

   procedure Process (Root : out Node_Id) is
   begin
      Root := P_AADL_Specification;
   end Process;

end Parser;
