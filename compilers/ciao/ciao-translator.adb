----------------------------------------
--                                    --
--       ----  ---     --  ----       --
--       -      -     - -  -  -       --
--       -      -    ----  -  -       --
--       ----  ---  -   -  ----       --
--                                    --
----------------------------------------
--  CORBA                             --
--  Interface for                     --
--  Ada'95 distributed systems annex  --
--  Objects                           --
----------------------------------------
--  Copyright (c) 1999                --
--  École nationale supérieure des    --
--  télécommunications                --
----------------------------------------

--  This unit generates a decorated IDL tree
--  by traversing the ASIS tree of a DSA package
--  specification.
--  $Id: //depot/ciao/main/ciao-translator.adb#36 $

with Ada.Exceptions;
with Ada.Wide_Text_Io;  use Ada.Wide_Text_Io;
with Ada.Characters.Handling; use  Ada.Characters.Handling;

with Asis.Clauses;
with Asis.Compilation_Units;
with Asis.Declarations;
with Asis.Definitions;
with Asis.Elements;
with Asis.Expressions;
with Asis.Iterator;
with Asis.Text;

with CIAO.ASIS_Queries; use CIAO.ASIS_Queries;
with CIAO.Filenames;    use CIAO.Filenames;
with CIAO.IDL_Tree;     use CIAO.IDL_Tree;
with CIAO.IDL_Syntax;   use CIAO.IDL_Syntax;
with CIAO.IDL_Syntax.Scoped_Names; use CIAO.IDL_Syntax.Scoped_Names;
with CIAO.Nlists;       use CIAO.Nlists;

with CIAO.Translator.Maps;  use CIAO.Translator.Maps;
with CIAO.Translator.State; use CIAO.Translator.State;

package body CIAO.Translator is

   use Asis;
   use Asis.Definitions;
   use Asis.Elements;
   use Asis.Expressions;
   use Asis.Declarations;

   use CIAO;

   ---------------------------------------------------
   -- Raise_Translation_Error                       --
   -- Print an error message and abort translation. --
   ---------------------------------------------------

   procedure Raise_Translation_Error
     (Element : Asis.Element;
      Message : String) is

      use Asis.Text;

      E_Span       : constant Span
        := Element_Span (Element);

      Line_Number_Wide_Image : Wide_String
        := Line_Number'Wide_Image (E_Span.First_Line);
      Character_Position_Wide_Image : Wide_String
        := Character_Position'Wide_Image
        (E_Span.First_Column);

      E_Lines : Line_List :=
        Lines (Element    => Element,
               First_Line => E_Span.First_Line,
               Last_Line  => E_Span.First_Line);
   begin
      New_Line;
      New_Line;
      Put (Line_Number_Wide_Image);
           -- (2 .. Line_Number_Wide_Image'Last));
      Put (". ");
      Put (Line_Image (E_Lines (E_Lines'First)));
      New_Line;

      for I in 1 .. E_Span.First_Column + Line_Number_Wide_Image'Length + 1 loop
         Put (' ');
      end loop;

      Put ('|');
      New_Line;
      Put (">>> ");

      Ada.Exceptions.Raise_Exception (Translation_Error'Identity, Message);
   end Raise_Translation_Error;

   ----------------------------------------------------------------------
   -- Unit_Category                                                    --
   -- Returns the category (Pure, RT, RCI or Other) of a library unit. --
   ----------------------------------------------------------------------

   function Unit_Category (LU : in Compilation_Unit)
     return Unit_Categories is
      D : constant Declaration := Unit_Declaration (LU);
      K : constant Declaration_Kinds := Declaration_Kind (D);
   begin
      -- Check that LU is a package specification
      if K /= A_Package_Declaration then
         Raise_Translation_Error (Nil_Element, "Unexpected unit declaration kind.");
      end if;

      -- Find the category of LU.
      declare
         Unit_Pragmas : constant Pragma_Element_List := Pragmas (D);
      begin
         for I in Unit_Pragmas'Range loop
            case Pragma_Kind (Unit_Pragmas (I)) is
               when A_Pure_Pragma =>
                  return Pure;
               when A_Remote_Types_Pragma =>
                  return Remote_Types;
               when A_Remote_Call_Interface_Pragma =>
                  return Remote_Call_Interface;
               when others =>
                  null;
            end case;
         end loop;

         return Other;
      end;
   end Unit_Category;

   --------------------------------------
   -- {Pre,Post}_Translate_Element     --
   -- The pre- and post-operations for --
   -- Asis.Iterator.Traverse_Element.  --
   --------------------------------------

   procedure Pre_Translate_Element
     (Element : in Asis.Element;
      Control : in out Traverse_Control;
      State   : in out Translator_State);

   procedure Post_Translate_Element
     (Element : in Asis.Element;
      Control : in out Traverse_Control;
      State   : in out Translator_State);

   -------------------------------------------
   -- Translate_Tree                        --
   -- Translate an Ada syntax tree into the --
   -- corresponding IDL tree.               --
   -------------------------------------------

   procedure Translate_Tree is new Iterator.Traverse_Element
     (State_Information => Translator_State,
      Pre_Operation     => Pre_Translate_Element,
      Post_Operation    => Post_Translate_Element);

   ------------------------------------------------------------------
   -- Process_*                                                    --
   -- Helper subprograms for Pre_Translate_Element that            --
   -- handle specific Element_Kinds.                               --
   -- These subprograms act strictly like Pre_Translate_Elements:  --
   -- the caller should return immediately to the Traverse_Element --
   -- instance after calling any of them.                          --
   ------------------------------------------------------------------

   procedure Process_Declaration
     (Element : in Asis.Element;
      Control : in out Traverse_Control;
      State   : in out Translator_State);
   procedure Process_Definition
     (Element : in Asis.Element;
      Control : in out Traverse_Control;
      State   : in out Translator_State);
   procedure Process_Expression
     (Element : in Asis.Element;
      Control : in out Traverse_Control;
      State   : in out Translator_State);
   procedure Process_Type_Definition
     (Element : in Asis.Element;
      Control : in out Traverse_Control;
      State   : in out Translator_State);

   ----------------------------------------------------------
   -- Translate_*                                          --
   -- These procedures are called by Pre_Translate_Element --
   -- to take care of particular Element_Kinds.            --
   ----------------------------------------------------------

   procedure Translate_Defining_Name
     (Name    : in Asis.Defining_Name;
      State   : in out Translator_State);

   procedure Translate_Subtype_Mark
     (Exp     : in Asis.Expression;
      State   : in out Translator_State);

   procedure Translate_Discriminant_Part
     (Def     : in Asis.Definition;
      State   : in out Translator_State);

   procedure Translate_Type_Definition
     (Def     : in Asis.Definition;
      State   : in out Translator_State);

   procedure Translate_Formal_Parameter
     (Specification    : in Asis.Definition;
      Is_Implicit_Self : in Boolean;
      State            : in out Translator_State);

   ---------------------------------------------------------------
   -- Pre_Translate_Element                                     --
   -- Translate an element into IDL.                            --
   -- Used as pre-operation for Iterator.Traverse_Element.      --
   ---------------------------------------------------------------

   procedure Pre_Translate_Element
     (Element : in Asis.Element;
      Control : in out Traverse_Control;
      State   : in out Translator_State) is
   begin
      case Element_Kind (Element) is
         when
           Not_An_Element       |
           A_Statement          |
           A_Path               |
           An_Exception_Handler =>
            Raise_Translation_Error
              (Element, "Unexpected element.");

         when A_Pragma =>
            -- XXX Ignore all pragmas for now. This is
            -- probably wrong. At *least* a pragma
            -- Asynchronous should be translated to a
            -- semantic marker.
            Control := Abandon_Children;

         when A_Defining_Name =>
            Translate_Defining_Name (Element, State);
            Control := Abandon_Children;

         when A_Declaration =>
            Process_Declaration (Element, Control, State);
         when A_Definition =>
            Process_Definition (Element, Control, State);
         when An_Expression =>
            Process_Expression (Element, Control, State);
         when An_Association =>
            -- XXX
            null;
         when A_Clause =>
            -- XXX
            Control := Abandon_Children;
      end case;
   exception
      when Ex : others =>
         Put_Line ("Unexpected exception in Pre_Translate_Element:");
         Put_Line (To_Wide_String (Ada.Exceptions.Exception_Name (Ex)) & ":");
         Put_Line (To_Wide_String (Ada.Exceptions.Exception_Information (Ex)));

         raise;
   end Pre_Translate_Element;

   procedure Process_Declaration
     (Element : in Asis.Element;
      Control : in out Traverse_Control;
      State   : in out Translator_State) is

      use Asis.Definitions;

      Node             : Node_Id;
      DK               : constant Declaration_Kinds
        := Declaration_Kind (Element);
      Defining_Names   : constant Defining_Name_List
        := Declarations.Names (Element);
      Defining_Name    : Asis.Defining_Name
        renames Defining_Names (Defining_Names'First);
      Old_Current_Node : constant Node_Id
        := State.Current_Node;

      -----------------------
      -- Local subprograms --
      -----------------------

      procedure Process_Distributed_Object_Declaration
        (Element : in Asis.Element;
         Control : in out Traverse_Control;
         State   : in out Translator_State);
      --  Process the declaration of a potentially
      --  distributed object (the declaration of any
      --  tagged limited private type).

      procedure Process_Operation_Declaration
        (State                   : in out Translator_State;
         Parameter_Profile       : Asis.Parameter_Specification_List;
         Result_Profile          : Asis.Element := Nil_Element;
         Implicit_Self_Parameter : Asis.Element := Nil_Element);
      --  Core processing for the declaration of a method of a
      --  remote entity, i. e. either a subprogram_declaration,
      --  or a full_type_declaration that declares a RAS.
      --
      --  State              - The translator state.
      --  Parameter_Profile  - The calling profile of the operation.
      --  Result_Profile     - The return profile (for a funtion),
      --                       Nil_Element (for a procedure).
      --  Implicit_Self_Parameter - The Parameter_Specification that
      --                       corresponds to the implicit "Self"
      --                       parameter, if this is a primitive operation
      --                       for a distributed object type, Nil_Element
      --                       otherwise.
      --
      --  Pre-condition:  State.Current_Node is the <interface_dcl>.
      --  Post-condition: State.Current_Node is the <op_dcl> node
      --  and its name has not been set.

      function Get_Constants_Interface (N : in Node_Id)
        return Node_Id;
      --  Returns the Node_Id of the <interface_dcl> node that
      --  contains all constants exported by the module;
      --  allocates it if it does not exist yet.

      procedure Process_Distributed_Object_Declaration
        (Element : in Asis.Element;
         Control : in out Traverse_Control;
         State   : in out Translator_State) is
         Forward_Node : Node_Id;
      begin
         Forward_Node := New_Forward_Interface;
         Set_Parent (Forward_Node, State.Current_Node);
         Add_Definition (State.Current_Node, Forward_Node);

         Node := New_Interface;
         Set_Parent (Node, State.Current_Node);
         Add_Interface (State.Current_Node, Node);

         State.Current_Node := Specific_Interface (Forward_Node);
         Translate_Defining_Name
           (Defining_Name, State);

         State.Current_Node := Interface_Header (Specific_Interface (Node));
         Translate_Defining_Name
           (Defining_Name, State);

         if DK = A_Private_Extension_Declaration then
            --  This is an extension of a distributed object declaration:
            --  either a private_extension_declaration or an
            --  ordinary_type_declaration which is a derived_type_declaration
            --  for a distributed object type, without an extension part.
            declare
               Ancestor_Definition : constant Asis.Defining_Name
                 := Corresponding_Entity_Name_Definition
                 (Asis.Definitions.Subtype_Mark
                  (Ancestor_Subtype_Indication
                   (Type_Declaration_View (Element))));
               Include_Node : constant Node_Id
                 := Get_Translation (Unit_Declaration
                                     (Enclosing_Compilation_Unit
                                      (Ancestor_Definition)));
            begin
               if Include_Node /= Empty
                 and then Node_Kind (Include_Node) = N_Preprocessor_Include
               then
                  Set_Unit_Used (Include_Node, True);
               end if;

               Add_Inherited_Interface
                 (State.Current_Node,
                  (Relative_Scoped_Name
                   (Denoted_Definition => Ancestor_Definition,
                    Referer            => Element)));
            end;
         else
            --  This is a root distributed object declaration.
            null;
         end if;
         State.Current_Node := Old_Current_Node;

         Set_Translation (Element, Specific_Interface (Node));
         --  The translation information for a tagged
         --  type definition is the corresponding
         --  <interface_dcl>.

         Control := Abandon_Children;
         --  Children were processed explicitly.
      end Process_Distributed_Object_Declaration;

      procedure Process_Operation_Declaration
        (State                   : in out Translator_State;
         Parameter_Profile       : Asis.Parameter_Specification_List;
         Result_Profile          : Asis.Element := Nil_Element;
         Implicit_Self_Parameter : Asis.Element := Nil_Element) is

         Op_Node         : Node_Id;
         --  The <op_dcl>
         Value_Type_Node : Node_Id;
         --  <param_type_spec> or "void", for use in <op_type_spec>.

      begin
         Op_Node := New_Operation;
         Set_Parent (Op_Node, State.Current_Node);
         Add_Export (State.Current_Node, Op_Node);

         if  Is_Nil (Result_Profile) then
            Value_Type_Node := New_Void;
         else
            Value_Type_Node := New_Node (N_Param_Type_Spec);
            State.Current_Node := Value_Type_Node;
            Translate_Subtype_Mark (Result_Profile, State);
         end if;

         Set_Parent (Value_Type_Node, Op_Type_Spec (Op_Node));
         Set_Operation_Value_Type (Op_Type_Spec (Op_Node), Value_Type_Node);

         State.Current_Node := Op_Node;

         for I in Parameter_Profile'Range loop
            if Is_Identical (Parameter_Profile (I),
                             Implicit_Self_Parameter) then
               Translate_Formal_Parameter
                 (Specification    => Parameter_Profile (I),
                  Is_Implicit_Self => True,
                  State            => State);
            else
               Translate_Formal_Parameter
                 (Specification    => Parameter_Profile (I),
                  Is_Implicit_Self => False,
                  State            => State);
            end if;
         end loop;
      end Process_Operation_Declaration;

      function Get_Constants_Interface (N : in Node_Id)
        return Node_Id is
         Interface_Node     : Node_Id;
         Interface_Dcl_Node : Node_Id;
      begin
         Interface_Dcl_Node := Constants_Interface (N);
         if No (Interface_Dcl_Node) then
            Interface_Node := New_Interface;
            Set_Parent (Interface_Node, State.Current_Node);
            Add_Interface (State.Current_Node, Interface_Node);

            Interface_Dcl_Node := Specific_Interface (Interface_Node);

            Set_Constants_Interface (State.Current_Node, Interface_Dcl_Node);
            Set_Name (Interface_Header (Interface_Dcl_Node),
                      New_Name ("Constants"));
         end if;

         return Interface_Dcl_Node;
      end Get_Constants_Interface;

   begin
      case DK is
         when
           An_Ordinary_Type_Declaration |                -- 3.2.1(3)
           A_Subtype_Declaration        |                -- 3.2.2(2)
           A_Task_Type_Declaration      |                -- 9.1(2)
           A_Protected_Type_Declaration =>               -- 9.4(2)
            declare
               Type_Definition      : constant Asis.Definition
                 := Declarations.Type_Declaration_View (Element);
            begin
               pragma Assert (Defining_Names'Length = 1);
               --  Only one defining_name in a full_type_declaration,
               --  subtype_declaration, task_type_declaration or
               --  protected_type_declaration.

               if True
                 and then Type_Kind (Type_Definition)
                   = An_Access_Type_Definition
                 and then Access_Type_Kind (Type_Definition)
                   in Access_To_Subprogram_Definition
               then
                  --  This is the definition of a Remote Access to
                  --  Subprogram type.
                  declare
                     Interface_Node : Node_Id;
                     Interface_Dcl_Node : Node_Id;
                  begin
                     Interface_Node := New_Interface;
                     Set_Parent (Interface_Node, State.Current_Node);
                     Add_Definition (State.Current_Node, Interface_Node);

                     Interface_Dcl_Node := Specific_Interface (Interface_Node);

                     State.Current_Node := Interface_Header
                       (Interface_Dcl_Node);
                     Translate_Defining_Name (Defining_Names
                                              (Defining_Names'First), State);
                     State.Current_Node := Interface_Dcl_Node;

                     case Access_Type_Kind (Type_Definition) is
                        when
                          An_Access_To_Procedure           |
                          An_Access_To_Protected_Procedure =>
                           Process_Operation_Declaration
                             (State, Access_To_Subprogram_Parameter_Profile
                              (Type_Definition));
                        when
                          An_Access_To_Function           |
                          An_Access_To_Protected_Function =>
                           Process_Operation_Declaration
                             (State,
                              Access_To_Subprogram_Parameter_Profile
                                (Type_Definition),
                              Result_Profile =>
                                Access_To_Function_Result_Profile
                                  (Type_Definition));
                        when others =>
                           --  This cannot happen because we checked that
                           --  Access_Kind in Access_To_Subprogram_Definition
                           raise ASIS_Failed;
                     end case;
                     Set_Name (State.Current_Node, New_Name ("Invoke"));
                     Set_Translation (Element, State.Current_Node);
                     --  The translation of a RAS declaration is
                     --  an <op_dcl>.
                  end;
               else
                  --  This is the definition of a normal type.
                  declare
                     Type_Dcl_Node        : Node_Id;
                     Type_Declarator_Node : Node_Id;
                     Declarator_Node      : Node_Id;
                  begin
                     Type_Dcl_Node := New_Node (N_Type_Dcl);
                     Set_Parent (Type_Dcl_Node, State.Current_Node);
                     Add_Definition (State.Current_Node, Type_Dcl_Node);
                     Set_Translation (Element, Type_Dcl_Node);
                     --  The translation of a type declaration is
                     --  a <type_dcl>.

                     Type_Declarator_Node := New_Node (N_Type_Declarator);
                     Set_Parent (Type_Declarator_Node, Type_Dcl_Node);
                     Set_Type_Declarator (Type_Dcl_Node, Type_Declarator_Node);

                     Declarator_Node := New_Node (N_Declarator);
                     Set_Parent (Declarator_Node, Type_Declarator_Node);
                     Add_Declarator (Type_Declarator_Node, Declarator_Node);

                     if False
                       --  For now, we cannot determine the bounds of a
                       --  static constrained array.
                       and then Definition_Kind (Type_Definition) = A_Type_Definition
                       and then Type_Kind (Type_Definition) = A_Constrained_Array_Definition
                     then
                        Node := New_Node (N_Array_Declarator);
                        Set_Parent (Node, Declarator_Node);
                        Set_Specific_Declarator (Declarator_Node, Node);

                        State.Current_Node := Node;
                        Translate_Defining_Name (Defining_Name, State);

                        --  Here we should process the array dimensions

                        raise Program_Error;
                     else
                        Node := New_Node (N_Simple_Declarator);
                        Set_Parent (Node, Declarator_Node);
                        Set_Specific_Declarator (Declarator_Node, Node);

                        State.Current_Node := Node;
                        Translate_Defining_Name
                          (Defining_Name, State);
                     end if;

                     --  known_discriminant_part is not processed now.
                     if DK = A_Subtype_Declaration then
                        declare
                           Type_Spec_Node : Node_Id;
                        begin
                           Type_Spec_Node := Insert_New_Simple_Type_Spec
                             (Type_Declarator_Node);

                           State.Current_Node := Specific_Type_Spec (Type_Spec_Node);
                           Translate_Subtype_Mark (Type_Definition, State);
                        end;
                     else
                        State.Current_Node := Type_Declarator_Node;
                        Translate_Type_Definition (Type_Definition, State);
                     end if;
                  end;
               end if;

               State.Current_Node := Old_Current_Node;

               Control := Abandon_Children;
               --  Children were processed explicitly.
            end;

         when An_Incomplete_Type_Declaration =>          -- 3.2.1(2), 3.10(2)
            --  An incomplete_type_declaration is translated
            --  when completed. The only place where the name
            --  could be used before completion in the context
            --  of CIAO is as part of an access_definition in
            --  the profile of a subprogram_declaration.
            --  Since the mapping of the subprogram_declaration
            --  is produced after all other definitions in the <module>,
            --  this is not an issue => we do nothing.

            Control := Abandon_Children;
            --  No child processing required.

         when A_Private_Type_Declaration =>              -- 3.2.1(2), 7.3(2)
            declare
               TK : Trait_Kinds := Trait_Kind (Element);
               Type_Definition  : constant Asis.Definition
                 := Declarations.Type_Declaration_View (Element);
            begin
               pragma Assert (Defining_Names'Length = 1);
               --  Only one defining_name in a private_type_declaration.

               if (TK = An_Abstract_Limited_Private_Trait
                   or else TK = A_Limited_Private_Trait)
                 and then Definition_Kind (Type_Definition)
                   = A_Tagged_Private_Type_Definition then
                  --  This is the declaration of a potentially
                  --  distributed object.

                  Process_Distributed_Object_Declaration
                    (Element, Control, State);

               else
                  --  For A_Private_Type_Declaration that is not
                  --  a tagged limited private (possibly abstract)
                  --  type declaration, the type is mapped to an
                  --  opaque sequence of octets.
                  declare
                     Type_Dcl_Node        : Node_Id;
                     Type_Declarator_Node : Node_Id;
                     Declarator_Node      : Node_Id;
                  begin
                     Type_Dcl_Node := New_Node (N_Type_Dcl);
                     Set_Parent (Type_Dcl_Node, State.Current_Node);
                     Add_Definition (State.Current_Node, Type_Dcl_Node);
                     Set_Translation (Element, Type_Dcl_Node);
                     --  The translation of a type declaration is a <type_dcl>.

                     Type_Declarator_Node := New_Node (N_Type_Declarator);
                     Set_Parent (Type_Declarator_Node, Type_Dcl_Node);
                     Set_Type_Declarator (Type_Dcl_Node, Type_Declarator_Node);

                     Declarator_Node := New_Node (N_Declarator);
                     Set_Parent (Declarator_Node, Type_Declarator_Node);
                     Add_Declarator (Type_Declarator_Node, Declarator_Node);

                     Node := New_Node (N_Simple_Declarator);
                     Set_Parent (Node, Declarator_Node);
                     Set_Specific_Declarator (Declarator_Node, Node);

                     State.Current_Node := Node;
                     Translate_Defining_Name
                       (Defining_Name, State);
                     declare
                        Opaque_Type_Node : constant Node_Id
                          := New_Opaque_Type;
                     begin
                        Set_Type_Spec (Type_Declarator_Node, Opaque_Type_Node);
                        Set_Parent (Opaque_Type_Node, Type_Declarator_Node);
                     end;
                     State.Current_Node := Old_Current_Node;
                  end;

                  Control := Abandon_Children;
                  --  Children were processed explicitly.
               end if;
            end;

         when A_Private_Extension_Declaration =>         -- 3.2.1(2), 7.3(3)
            declare
               Ancestor_Definition : constant Asis.Defining_Name
                 := Corresponding_Entity_Name_Definition
                  (Asis.Definitions.Subtype_Mark
                   (Ancestor_Subtype_Indication
                    (Type_Declaration_View (Element))));
            begin
               pragma Assert (Defining_Names'Length = 1);
               --  Only one defining_name in a private_extension_declaration.

               if Is_Limited_Type (Element) then
                  --  A private_extension_declaration declares
                  --  a tagged private type. If it is limited as well,
                  --  then it is an extension of a potentially
                  --  distributed object.

                  Process_Distributed_Object_Declaration
                    (Element, Control, State);

               end if;
               --  For A_Private_Extension_Declaration that is not
               --  a tagged limited private (possibly abstract)
               --  type declaration, the implicit processing is done,
               --  resulting in an opaque type mapping.
               -- NOT CHECKED!
            end;

         when
           A_Variable_Declaration         |              -- 3.3.1(2)
           A_Single_Task_Declaration      |              -- 3.3.1(2), 9.1(3)
           A_Single_Protected_Declaration =>             -- 3.3.1(2), 9.4(2)
            Raise_Translation_Error
              (Element, "Unexpected variable declaration (according to unit categorization).");

         when
           A_Constant_Declaration          |             -- 3.3.1(4)
           A_Deferred_Constant_Declaration |             -- 3.3.1(6), 7.4(2)
           An_Integer_Number_Declaration   |             -- 3.3.2(2)
           A_Real_Number_Declaration       =>            -- 3.5.6(2)
            declare
               Interface_Dcl_Node : constant Node_Id
                 := Get_Constants_Interface (State.Current_Node);
               Op_Node         : Node_Id;
               --  The <op_dcl>
               Value_Type_Node : Node_Id;
               --  <param_type_spec> or "void", for use in <op_type_spec>.
            begin
               for I in Defining_Names'Range loop
                  --  A constant is mapped to a parameter-less operation
                  --  in the "Constants" <interface_dcl> of the current
                  --  <module>.
                  Op_Node := New_Operation;
                  Set_Parent (Op_Node, Interface_Dcl_Node);
                  Add_Export (Interface_Dcl_Node, Op_Node);

                  --  Set the <op_type_spec> to the <param_type_spec>
                  --  that corresponds to the constant's subtype.
                  Value_Type_Node := New_Node (N_Param_Type_Spec);
                  State.Current_Node := Value_Type_Node;
                  if False
                    or else DK = A_Constant_Declaration
                    or else DK = A_Deferred_Constant_Declaration
                  then
                     declare
                        Object_Definition : constant Asis.Definition
                          := Object_Declaration_View (Element);
                     begin
                        case Definition_Kind (Object_Definition) is
                           when A_Subtype_Indication =>
                              Translate_Subtype_Mark
                                (Asis.Definitions.Subtype_Mark (Object_Definition), State);
                           when A_Type_Definition => --  A_Constrained_Array_Definition
                              -- XXX TODO:
                              -- * emit a type <name_of_constant>_array
                              -- * map the constant to a function which returns that type.
                              -- (an IDL function cannot return an anonymous array.)
                              raise Program_Error;

                           when others =>
                              Raise_Translation_Error
                                (Element, "Unexpected object definition (A_Constant_Declaration).");
                        end case;
                     end;
                  else
                     --  An_Integer_Number_Declaration or A_Real_Number_Declaration
                     -- XXX This code is more or less replicated in An_Unconstrained_Array_Definition
                     --     and should be factored.
                     declare
                        TS_Node : Node_Id;
                        STS_Node : Node_Id;
                        BTS_Node : Node_Id;
                     begin
                        TS_Node := Insert_New_Simple_Type_Spec (State.Current_Node);

                        STS_Node := Specific_Type_Spec (TS_Node);

                        if DK = An_Integer_Number_Declaration then
                           BTS_Node := New_Base_Type (Base_Type (Root_Integer));
                        else
                           BTS_Node := New_Base_Type (Base_Type (Root_Real));
                        end if;

                        Set_Base_Type_Spec (STS_Node, BTS_Node);
                        Set_Parent (BTS_Node, STS_Node);
                     end;
                  end if;

                  Set_Parent (Value_Type_Node, Op_Type_Spec (Op_Node));
                  Set_Operation_Value_Type (Op_Type_Spec (Op_Node), Value_Type_Node);

                  State.Current_Node := Op_Node;
                  Translate_Defining_Name (Defining_Names (I), State);
                  Set_Translation (Element, State.Current_Node);
                  --  The translation of a constant declaration is the
                  --  corresponding <op_dcl>.

                  State.Current_Node := Old_Current_Node;
               end loop;

               Control := Abandon_Children;
               --  Child elements were processed explicitly.
            end;

         when An_Enumeration_Literal_Specification =>    -- 3.5.1(3)
            declare
               Enumerator_Node : Node_Id;
            begin
               pragma Assert (Defining_Names'Length = 1);
               --  Only one defining_name in an enumeration_literal_specification.

               Enumerator_Node := Insert_New_Enumerator (State.Current_Node);

               State.Current_Node := Enumerator_Node;
               Translate_Defining_Name (Defining_Name, State);
               State.Current_Node := Old_Current_Node;

               Control := Abandon_Children;
               --  Children were processed explicitly.
            end;

         when
           A_Discriminant_Specification |                -- 3.7(5)
           A_Component_Declaration      =>               -- 3.8(6)
            declare
               Component_Subtype_Mark : Asis.Expression;
               Declarator_Node        : Node_Id;
               Simple_Declarator_Node : Node_Id;
               Type_Spec_Node         : Node_Id;
            begin
               if DK = A_Discriminant_Specification then
                  Component_Subtype_Mark := Declaration_Subtype_Mark (Element);
               else
                  Component_Subtype_Mark := Asis.Definitions.Subtype_Mark
                    (Component_Subtype_Indication
                     (Object_Declaration_View (Element)));
               end if;

               Node := Insert_New_Member (State.Current_Node);

               for I in Defining_Names'Range loop
                  Declarator_Node := New_Node (N_Declarator);
                  Set_Parent (Declarator_Node, Node);
                  Add_Declarator (Node, Declarator_Node);

                  Simple_Declarator_Node := New_Node (N_Simple_Declarator);
                  Set_Parent (Simple_Declarator_Node, Declarator_Node);
                  Set_Specific_Declarator
                    (Declarator_Node, Simple_Declarator_Node);

                  State.Current_Node := Simple_Declarator_Node;
                  Translate_Defining_Name (Defining_Names (I), State);
               end loop;

               Type_Spec_Node := Insert_New_Simple_Type_Spec (Node);

               State.Current_Node := Specific_Type_Spec (Type_Spec_Node);
               Translate_Subtype_Mark (Component_Subtype_Mark, State);
               State.Current_Node := Old_Current_Node;

               Control := Abandon_Children;
               --  Child elements were processed explicitly.
            end;

         when
           A_Procedure_Declaration |                     -- 6.1(4)
           A_Function_Declaration  =>                    -- 6.1(4)
            declare
               Is_Function             : constant Boolean
                 := (DK = A_Function_Declaration);
               Profile                 : constant Parameter_Specification_List
                 := Parameter_Profile (Element);
               Implicit_Self_Parameter : Asis.Element := Nil_Element;
               Interface_Dcl_Node      : Node_Id := Empty;
               Old_Current_Node        : constant Node_Id
                 := State.Current_Node;
            begin
               pragma Assert (Defining_Names'Length = 1);
               --  Only one defining_name in a subprogram declaration.

               if State.Unit_Category = Remote_Call_Interface then
                  --  This is a remote subprogram of an RCI unit:
                  --  the current scope is the <interface> that maps
                  --  that unit.
                  Interface_Dcl_Node := State.Current_Node;
               else
                  declare
                     Controlling_Formals : constant Parameter_Specification_List
                       := Controlling_Formal_Parameters (Element);
                     Tagged_Type_Declaration : Declaration
                       := Nil_Element;
                  begin
                     --  First determine if this is a primitive operation
                     --  of a tagged type.

                     if Is_Function then
                        declare
                           Subtype_Mark : constant Asis.Expression
                             := Result_Profile (Element);
                           Subtype_Declaration : constant Asis.Declaration
                             := Corresponding_Entity_Name_Declaration (Subtype_Mark);
                        begin
                           if Is_Controlling_Result (Subtype_Mark) then
                              Tagged_Type_Declaration :=
                                Corresponding_First_Subtype (Subtype_Declaration);
                           end if;
                        end;
                     end if;

                     if Is_Nil (Tagged_Type_Declaration)
                       and then Controlling_Formals'Length > 0 then
                        Implicit_Self_Parameter := Controlling_Formals (Controlling_Formals'First);
                        Tagged_Type_Declaration :=
                          Corresponding_First_Subtype
                          (Corresponding_Entity_Name_Declaration
                           (Declaration_Subtype_Mark (Implicit_Self_Parameter)));
                     end if;

                     if True
                       and then not Is_Nil (Tagged_Type_Declaration)
                       and then not Is_Overriding_Inherited_Subprogram
                         (Element, Tagged_Type_Declaration)
                     then
                        --  This is a new dispatching operation of a tagged type
                        --  (it does not override an inherited operation).
                        --  Obtain the corresponding <interface_dcl> node.

                        -- XXX For now, we do not check whether this operation overrides
                        -- another with a different signature. In that case, erroneous
                        -- IDL is produced!
                        Interface_Dcl_Node := Get_Translation (Tagged_Type_Declaration);
                     end if;
                  end;
               end if;

               --  At this point, if the subprogram is remote, then the corresponding
               --  <interface> is part of the current <specification>, and
               --  Interface_Dcl_Node is set to the corresponding N_Interface node.

               if Node_Kind (Interface_Dcl_Node) = N_Interface_Dcl then
                  State.Current_Node := Interface_Dcl_Node;
                  if Is_Function then
                     Process_Operation_Declaration (State, Profile,
                                                    Result_Profile => Result_Profile (Element),
                                                    Implicit_Self_Parameter => Implicit_Self_Parameter);
                  else
                     Process_Operation_Declaration (State, Profile,
                                                    Result_Profile => Nil_Element,
                                                    Implicit_Self_Parameter => Implicit_Self_Parameter);
                  end if;
                  Translate_Defining_Name (Defining_Name, State);
                  Set_Translation (Element, State.Current_Node);
                  --  The translation of a subprogram declaration is the corresponding
                  --  <op_dcl>.
               end if;

               State.Current_Node := Old_Current_Node;
               Control := Abandon_Children;
               --  Children were processed explicitly.
            end;

         when A_Parameter_Specification =>               -- 6.1(15)
            declare
               Defining_Names   : constant Defining_Name_List
                 := Declarations.Names (Element);
               Subtype_Mark     : constant Asis.Expression
                 := Declarations.Declaration_Subtype_Mark (Element);
               Attribute_Node        : Node_Id;
               Old_Current_Node : constant Node_Id
                 := State.Current_Node;
            begin
               pragma Assert (False
                 or else State.Pass = CIAO.Translator.State.Self_Formal_Parameter
                 or else State.Pass = CIAO.Translator.State.Normal_Formal_Parameter);

               for I in Defining_Names'Range loop
                  if State.Pass /= Self_Formal_Parameter
                    or else I /= Defining_Names'First then
                     Node := New_Parameter;
                     Set_Parent (Node, State.Current_Node);
                     Add_Param_Dcl (State.Current_Node, Node);

                     State.Current_Node := Node;
                     Translate_Defining_Name (Defining_Names (I), State);

                     State.Current_Node := Param_Type_Spec (Node);
                     Translate_Subtype_Mark (Subtype_Mark, State);

                     State.Current_Node := Old_Current_Node;

                     if Trait_Kind (Element) = An_Access_Definition_Trait then
                        Attribute_Node := New_Inout_Attribute;
                     else
                        case Mode_Kind (Element) is
                           when Not_A_Mode     =>          -- An unexpected element
                              Raise_Translation_Error
                              (Element, "Unexpected element (Not_A_Mode).");
                           when
                             A_Default_In_Mode |           -- procedure A(B :        C);
                             An_In_Mode        =>          -- procedure A(B : IN     C);
                              Attribute_Node := New_In_Attribute;
                           when An_Out_Mode    =>          -- procedure A(B :    OUT C);
                              Attribute_Node := New_Out_Attribute;
                           when An_In_Out_Mode =>          -- procedure A(B : IN OUT C);
                              Attribute_Node := New_Inout_Attribute;
                        end case;
                     end if;
                     Set_Parent (Attribute_Node, Node);
                     Set_Parameter_Attribute (Node, Attribute_Node);
                  end if;
               end loop;
            end;

            Control := Abandon_Children;
            --  Children were processed explicitly.

         when A_Package_Declaration =>                   -- 7.1(2)
            declare
               Defining_Names : constant Definition_List
                 := Names (Element);
               Visible_Part : constant Declarative_Item_List
                 := Declarations.Visible_Part_Declarative_Items
                 (Declaration => Element,
                  Include_Pragmas => True);

               Interface_Dcl_Node : Node_Id;
            begin

               if State.Unit_Category = Remote_Call_Interface then

                  --  The translation of a Remote Call Interface is an <interface>

                  Node := New_Interface;
                  Set_Parent (Node, State.Current_Node);
                  Add_Interface (State.Current_Node, Node);

                  Interface_Dcl_Node := Specific_Interface (Node);
                  Set_Is_Remote_Subprograms (Interface_Dcl_Node, True);

                  State.Current_Node := Interface_Header (Interface_Dcl_Node);
                  Translate_Defining_Name (Defining_Name, State);
                  State.Current_Node := Interface_Dcl_Node;
               else

                  --  The translation of a non-RCI package declaration is a <module>

                  Node := New_Node (N_Module);
                  Set_Parent (Node, State.Current_Node);
                  Add_Definition (State.Current_Node, Node);
                  Set_Translation (Element, Node);
                  State.Current_Node := Node;
                  Translate_Defining_Name (Defining_Name, State);
               end if;

           Do_Visible_Part:
               for I in Visible_Part'Range loop
                  Translate_Tree (Visible_Part (I), Control, State);
                  if Control = Abandon_Siblings then
                     exit Do_Visible_Part;
                  end if;
               end loop Do_Visible_Part;

               State.Current_Node := Old_Current_Node;

               Control := Abandon_Children;
               --  Children were processed explicitly.
            end;

         when
           A_Procedure_Body_Declaration    |             -- 6.3(2)
           A_Function_Body_Declaration     |             -- 6.3(2)
           A_Task_Body_Declaration         |             -- 9.1(6)
           A_Protected_Body_Declaration    |             -- 9.4(7)
           A_Package_Body_Declaration      |             -- 7.2(2)
           A_Procedure_Body_Stub           |             -- 10.1.3(3)
           A_Function_Body_Stub            |             -- 10.1.3(3)
           A_Package_Body_Stub             |             -- 10.1.3(4)
           A_Task_Body_Stub                |             -- 10.1.3(5)
           A_Protected_Body_Stub           |             -- 10.1.3(6)
           An_Entry_Body_Declaration       =>            -- 9.5.2(5)
            Raise_Translation_Error
              (Element, "Unexpected body declaration.");

         when
           An_Exception_Declaration        |             -- 11.1(2)
           --  User-defined exceptions need not be
           --  mapped, as all Ada exceptions are propagated
           --  as ::CIAO::Ada_Exception.
           A_Generic_Procedure_Declaration |             -- 12.1(2)
           A_Generic_Function_Declaration  |             -- 12.1(2)
           A_Generic_Package_Declaration   =>            -- 12.1(2)
           --  Generic declarations define no exported services,
           --  and are therefore not mapped.
            Control := Abandon_Children;

         when
           A_Package_Instantiation                  |    -- 12.3(2)
           A_Procedure_Instantiation                |    -- 12.3(2)
           A_Function_Instantiation                 |    -- 12.3(2)

           An_Object_Renaming_Declaration           |    -- 8.5.1(2)
           An_Exception_Renaming_Declaration        |    -- 8.5.2(2)
           A_Package_Renaming_Declaration           |    -- 8.5.3(2)
           A_Procedure_Renaming_Declaration         |    -- 8.5.4(2)
           A_Function_Renaming_Declaration          |    -- 8.5.4(2)
           A_Generic_Package_Renaming_Declaration   |    -- 8.5.5(2)
           A_Generic_Procedure_Renaming_Declaration |    -- 8.5.5(2)
           A_Generic_Function_Renaming_Declaration  =>   -- 8.5.5(2)
           --  These constructs are not supported due to
           --  restrictions placed by the translation specification.
            Raise_Translation_Error
              (Element, "Construct not supported by translation schema.");

         when
           Not_A_Declaration                |            -- An unexpected element
           A_Loop_Parameter_Specification   |            -- 5.5(4)
           An_Entry_Declaration             |            -- 9.5.2(2)
           An_Entry_Index_Specification     |            -- 9.5.2(2)
           A_Choice_Parameter_Specification |            -- 11.2(4)
           A_Formal_Object_Declaration      |            -- 12.4(2)
           A_Formal_Type_Declaration        |            -- 12.5(2)
           A_Formal_Procedure_Declaration   |            -- 12.6(2)
           A_Formal_Function_Declaration    |            -- 12.6(2)
           A_Formal_Package_Declaration     |            -- 12.7(2)
           A_Formal_Package_Declaration_With_Box =>      -- 12.7(3)
            Raise_Translation_Error
              (Element, "Unexpected element (A_Declaration).");
      end case;
   end Process_Declaration;

   procedure Process_Definition
     (Element : in Asis.Element;
      Control : in out Traverse_Control;
      State   : in out Translator_State) is
   begin
      case Definition_Kind (Element) is
         when Not_A_Definition =>                 -- An unexpected element
            Raise_Translation_Error
              (Element, "Unexpected element (A_Definition).");

         when A_Type_Definition =>                -- 3.2.1(4)
            Process_Type_Definition (Element, Control, State);

         when A_Subtype_Indication =>             -- 3.2.2(3)
            --  Process child nodes:
            --  translate subtype_mark, ignore constraint.
            null;

         when A_Constraint =>                     -- 3.2.2(5)
            --  Constraints cannot be represented in OMG IDL
            --  and are therefore ignored.
            Control := Abandon_Children;

         when A_Discrete_Subtype_Definition =>    -- 3.6(6)
            -- XXX Does this ever happen?
            raise Program_Error;

         when A_Discrete_Range =>                 -- 3.6.1(3)
            -- XXX Does this ever happen?
            raise Program_Error;

         when An_Unknown_Discriminant_Part =>     -- 3.7(3)
            -- XXX Does this ever happen?
            raise Program_Error;

         when A_Known_Discriminant_Part =>        -- 3.7(2)
            if State.Pass = Deferred_Discriminant_Part then
               null;
               --  Process child nodes recursively.
            else
               Control := Abandon_Children;
               --  Processing is deferred to within type definition.
            end if;

         when
           A_Component_Definition   |             -- 3.6(7)
           A_Record_Definition      |             -- 3.8(3)
            --  Process child nodes.
           A_Null_Record_Definition |             -- 3.8(3)
           A_Null_Component         =>            -- 3.8(4)
            --  Nothing to do, no child elements.
            null;

         when A_Variant_Part =>                   -- 3.8.1(2)
            -- XXX TODO
            null;

         when A_Variant =>                        -- 3.8.1(3)
            -- XXX TODO
            null;

         when An_Others_Choice =>                 -- 3.8.1(5) => 4.3.1(5) => 4.3.3(5) => 11.2(5)
            -- XXX
            null;

         when
           A_Private_Type_Definition        |     -- 7.3(2)
           A_Tagged_Private_Type_Definition |     -- 7.3(2)
           A_Private_Extension_Definition   =>    -- 7.3(3)
            -- XXX Does this ever happen? (should not)
            raise Program_Error;

         when
           A_Task_Definition      |               -- 9.1(4)
           A_Protected_Definition =>              -- 9.4(4)
            --  A task type or protected type.
            declare
               Type_Spec_Node : Node_Id;
            begin
               Type_Spec_Node := Insert_New_Opaque_Type (State.Current_Node);

               Control := Abandon_Children;
               --  Children not processed (the mapping is opaque).
            end;

         when A_Formal_Type_Definition =>         -- 12.5(3)
            -- XXX Does this ever happen ? We are not supposed to support generics?!?!
            raise Program_Error;

      end case;
   end Process_Definition;

   --  Get a <base_type_spec> corresponding to a standard type definition.
   function Base_Type_For_Standard_Definition (Element : Asis.Type_Definition)
     return Node_Id is
      BTS_Node : Node_Id;
   begin
      if Definition_Kind (Element) = A_Subtype_Indication then
         --  Unwind all levels of subtyping.
         return Base_Type_For_Standard_Definition
           (Type_Declaration_View
            (Corresponding_Entity_Name_Declaration
             (Asis.Definitions.Subtype_Mark (Element))));
      else
         case Type_Kind (Element) is
            when A_Signed_Integer_Type_Definition =>
               BTS_Node := New_Base_Type (Base_Type (Root_Integer));
            when A_Modular_Type_Definition =>
               BTS_Node := New_Base_Type (Base_Type (Root_Modular));
            when
              A_Floating_Point_Definition        |
              An_Ordinary_Fixed_Point_Definition |
              A_Decimal_Fixed_Point_Definition   =>
               BTS_Node := New_Base_Type (Base_Type (Root_Real));
            when An_Enumeration_Type_Definition =>
            --  This is "Boolean".
               BTS_Node := New_Base_Type (Base_Type (Root_Boolean));
            when An_Unconstrained_Array_Definition =>
               --  This is "String".
               BTS_Node := New_Base_Type (Base_Type (Root_String));
            when others =>
               -- XXX Error should not happen
               Raise_Translation_Error
                 (Element, "Unexpected standard type definition.");
         end case;
         return BTS_Node;
      end if;
   end Base_Type_For_Standard_Definition;

   procedure Process_Expression
     (Element : in Asis.Element;
      Control : in out Traverse_Control;
      State   : in out Translator_State) is
      EK : constant Asis.Expression_Kinds
        := Expression_Kind (Element);
   begin
      case EK is
         when Not_An_Expression =>                -- An unexpected element
            Raise_Translation_Error
              (Element, "Unexpected element (Not_An_Expression).");

         when
           An_Identifier        |                 -- 4.1
           A_Selected_Component =>                -- 4.1.3
            --  The expression shall be translated as
            --  a <scoped_name>. State.Current_Node shall
            --  accept a <scoped_name> subnode.
            declare

               use Asis.Compilation_Units;

               Name_Definition : constant Asis.Element
                 := Corresponding_Entity_Name_Definition (Element);
               Origin          : constant Compilation_Unit :=
                 Enclosing_Compilation_Unit (Name_Definition);
               --  The library unit where the name is declared.
               Node : Node_Id;
            begin
               if Is_Nil (Corresponding_Parent_Declaration (Origin)) then
                  --  Element is a subtype_mark that denotes a type
                  --  declared in predefined package Standard.
                  Node := Base_Type_For_Standard_Definition (Type_Declaration_View
                                                         (Enclosing_Element
                                                          (Name_Definition)));
                  Set_Base_Type_Spec (State.Current_Node, Node);
                  Set_Parent (Node, State.Current_Node);
               else
                  declare
                     Include_Node : constant Node_Id
                       := Get_Translation (Unit_Declaration (Origin));
                  begin
                     if Include_Node /= Empty
                       and then Node_Kind (Include_Node) = N_Preprocessor_Include
                     then
                        Set_Unit_Used (Include_Node, True);
                     end if;
                     Node := Relative_Scoped_Name
                       (Denoted_Definition => Name_Definition,
                        Referer            => Element);
                     Set_Scoped_Name (State.Current_Node, Node);
                     Set_Parent (Node, State.Current_Node);
                  end;
               end if;

               Control := Abandon_Children;
               --  Children were processed explicitly.
            end;

         when An_Attribute_Reference =>           -- 4.1.4
            case Attribute_Kind (Element) is
               when
                 A_Base_Attribute  |
                 A_Class_Attribute =>
                  Translate_Subtype_Mark (Prefix (Element), State);

                  Control := Abandon_Children;
                  --  Children were processed explicitly.
               when others =>
                  Raise_Translation_Error
                    (Element, "Unexpected element (An_Attribute_Reference).");
            end case;

         ------------------------------------------------------
         -- All other Expression_Kinds are inappropriate.    --
         -- Encountering one of these cases denotes a bug in --
         -- either the Ada/ASIS environment or CIAO.         --
         ------------------------------------------------------

         when
           An_Integer_Literal     |               -- 2.4
           A_Real_Literal         |               -- 2.4.1
           A_String_Literal       |               -- 2.6
           A_Character_Literal    |               -- 4.1
           An_Enumeration_Literal |               -- 4.1
           A_Null_Literal         =>              -- 4.4
            Raise_Translation_Error
              (Element, "Unexpected element (a literal).");

         when
           An_Operator_Symbol      |              -- 4.1
           A_Function_Call         =>             -- 4.1
            Raise_Translation_Error
              (Element, "Unexpected element (a function or operator).");

         when
           An_Explicit_Dereference |              -- 4.1
           An_Indexed_Component |                 -- 4.1.1
           A_Slice              =>                -- 4.1.2
            Raise_Translation_Error
              (Element, "Unexpected element (an indexed reference or explicit dereference).");

         when
           A_Record_Aggregate           |         -- 4.3
           An_Extension_Aggregate       |         -- 4.3
           A_Positional_Array_Aggregate |         -- 4.3
           A_Named_Array_Aggregate      =>        -- 4.3
            Raise_Translation_Error
              (Element, "Unexpected element (an aggregate).");

         when
           An_And_Then_Short_Circuit      |       -- 4.4
           An_Or_Else_Short_Circuit       |       -- 4.4
           An_In_Range_Membership_Test    |       -- 4.4
           A_Not_In_Range_Membership_Test |       -- 4.4
           An_In_Type_Membership_Test     |       -- 4.4
           A_Not_In_Type_Membership_Test  |       -- 4.4
           A_Parenthesized_Expression     |       -- 4.4
           A_Type_Conversion              |       -- 4.6
           A_Qualified_Expression         =>      -- 4.7
            Raise_Translation_Error
              (Element, "Unexpected element (An_Expression).");

         when
           An_Allocation_From_Subtype |           -- 4.8
           An_Allocation_From_Qualified_Expression => -- 4.8
            Raise_Translation_Error
              (Element, "Unexpected element (an allocator).");
      end case;
   end Process_Expression;

   procedure Process_Type_Definition
     (Element : in Asis.Element;
      Control : in out Traverse_Control;
      State   : in out Translator_State) is
      Type_Spec_Node   : Node_Id;
      Old_Current_Node : constant Node_Id
        := State.Current_Node;
      TK : constant Asis.Type_Kinds
        := Type_Kind (Element);
   begin
      --  Translate the Element into a <type_spec>, and set the
      --  <type_spec> of State.Current_Node to that.

      case TK is
         when Not_A_Type_Definition =>                 -- An unexpected element
            Raise_Translation_Error
              (Element, "Unexpected element (Not_A_Type_Definition).");

         when A_Root_Type_Definition =>                -- 3.5.4(14) => 3.5.6(3)
            Raise_Translation_Error
              (Element, "Unexpected implicit element (A_Root_Type_Definition).");

         when A_Derived_Type_Definition =>             -- 3.4(2)
            Type_Spec_Node := Insert_New_Simple_Type_Spec (State.Current_Node);

            State.Current_Node := Specific_Type_Spec (Type_Spec_Node);
            Translate_Subtype_Mark
              (Asis.Definitions.Subtype_Mark
               (Asis.Definitions.Parent_Subtype_Indication (Element)), State);
            State.Current_Node := Old_Current_Node;

            Control := Abandon_Children;
            --  Children were processed explicitly.

         when An_Enumeration_Type_Definition =>        -- 3.5.1(2)
            declare
               Enum_Type_Node  : Node_Id;
               Type_Identifier : Name_Id;
            begin
               Type_Spec_Node := Insert_New_Constructed_Type (State.Current_Node);

               Enum_Type_Node := New_Node (N_Enum_Type);
               Set_Parent (Enum_Type_Node, Specific_Type_Spec (Type_Spec_Node));
               Set_Structure (Specific_Type_Spec (Type_Spec_Node), Enum_Type_Node);

               Type_Identifier := IDL_Syntax.Name
                 (Specific_Declarator (First (Declarators (State.Current_Node))));

               Set_Name (Enum_Type_Node, New_Constructed_Type_Identifier (Type_Identifier, "enum"));

               Set_Previous_Current_Node (Element, State.Current_Node);
               State.Current_Node := Enum_Type_Node;
            end;
            --  Process all children recursively.

         when
           A_Signed_Integer_Type_Definition   |        -- 3.5.4(3)
           A_Modular_Type_Definition          |        -- 3.5.4(4)
           A_Floating_Point_Definition        |        -- 3.5.7(2)
           An_Ordinary_Fixed_Point_Definition |        -- 3.5.9(3)
           A_Decimal_Fixed_Point_Definition   =>       -- 3.5.9(6)
            declare
               STS_Node : Node_Id;
               BTS_Node : Node_Id;
            begin
               Type_Spec_Node := Insert_New_Simple_Type_Spec (State.Current_Node);

               STS_Node := Specific_Type_Spec (Type_Spec_Node);

               BTS_Node := Base_Type_For_Standard_Definition (Element);

               Set_Base_Type_Spec (STS_Node, BTS_Node);
               Set_Parent (BTS_Node, STS_Node);
            end;

            Control := Abandon_Children;
            --  Children were processed explicitly.

         when
           An_Unconstrained_Array_Definition |         -- 3.6(2)
           A_Constrained_Array_Definition    =>        -- 3.6(2)
            declare
               Component_Subtype_Mark : constant Asis.Expression
                 := Asis.Definitions.Subtype_Mark
                  (Component_Subtype_Indication
                   (Array_Component_Definition (Element)));
            begin
               if Is_Limited_Type (Corresponding_Entity_Name_Declaration (Component_Subtype_Mark)) then
                  Type_Spec_Node := Insert_New_Opaque_Type (State.Current_Node);
               else
                  declare
                     Dimensions        : Natural;
                     Parent_Node       : Node_Id;
                     Struct_Type_Node  : Node_Id;
                     Member_Node       : Node_Id;
                     Declarator_Node   : Node_Id;
                     S_Declarator_Node : Node_Id;
                     Member_Type_Node  : Node_Id;

                     Type_Identifier   : Name_Id;
                  begin
                     if TK = An_Unconstrained_Array_Definition then
                        Dimensions := Index_Subtype_Definitions (Element)'Length;
                     else
                        Dimensions := Discrete_Subtype_Definitions (Element)'Length;
                     end if;

                     Type_Spec_Node := Insert_New_Constructed_Type (State.Current_Node);

                     Struct_Type_Node := New_Node (N_Struct_Type);
                     Set_Parent (Struct_Type_Node, Specific_Type_Spec (Type_Spec_Node));
                     Set_Structure (Specific_Type_Spec (Type_Spec_Node), Struct_Type_Node);

                     Type_Identifier := IDL_Syntax.Name
                       (Specific_Declarator (First (Declarators (State.Current_Node))));

                     Set_Name (Struct_Type_Node, New_Constructed_Type_Identifier
                               (Type_Identifier, "struct"));

                     ----------------------------------------------------------
                     -- <member>: unsigned long long Low_Bound;              --
                     --        OR unsigned long long Low_Bounds[DIMENSIONS]; --
                     ----------------------------------------------------------

                     Member_Node := Insert_New_Member (Struct_Type_Node);

                     Declarator_Node := New_Node (N_Declarator);
                     Set_Parent (Declarator_Node, Member_Node);
                     Add_Declarator (Member_Node, Declarator_Node);

                     if Dimensions = 1 then
                        S_Declarator_Node := New_Node (N_Simple_Declarator);
                        Set_Name (S_Declarator_Node, New_Name ("Low_Bound"));
                     else
                        declare
                           Size_Node : Node_Id;
                        begin
                           S_Declarator_Node := New_Node (N_Array_Declarator);
                           Set_Name (S_Declarator_Node, New_Name ("Low_Bounds"));

                           Size_Node := New_Node (N_Fixed_Array_Size);
                           Add_Fixed_Array_Size (S_Declarator_Node, Size_Node);
                           Set_Parent (Size_Node, S_Declarator_Node);

                           Set_Size_Value (Size_Node, Unbiased_Uint (Dimensions));
                        end;
                     end if;

                     Set_Parent (S_Declarator_Node, Declarator_Node);
                     Set_Specific_Declarator
                       (Declarator_Node, S_Declarator_Node);

                     --  Set type of member to unsigned long long.
                     declare
                        TS_Node : Node_Id;
                        STS_Node : Node_Id;
                        BTS_Node : Node_Id;
                     begin
                        TS_Node := Insert_New_Simple_Type_Spec (Member_Node);
                        STS_Node := Specific_Type_Spec (TS_Node);
                        BTS_Node := New_Base_Type (Base_Type (Root_Integer));

                        Set_Base_Type_Spec (STS_Node, BTS_Node);
                        Set_Parent (BTS_Node, STS_Node);
                     end;

                     -----------------------------------------------------------
                     -- <member>: sequence<sequence<...<TYPE>>> Array_Values; --
                     --                                                       --
                     -- For now, we cannot determine the bounds of a static   --
                     -- constrained array, so we always map all arrays to     --
                     -- sequences.                                            --
                     -----------------------------------------------------------

                     Member_Node := Insert_New_Member (Struct_Type_Node);

                     Declarator_Node := New_Node (N_Declarator);
                     Set_Parent (Declarator_Node, Member_Node);
                     Add_Declarator (Member_Node, Declarator_Node);

                     S_Declarator_Node := New_Node (N_Simple_Declarator);
                     Set_Parent (S_Declarator_Node, Declarator_Node);
                     Set_Specific_Declarator
                       (Declarator_Node, S_Declarator_Node);

                     Set_Name (S_Declarator_Node, New_Name ("Array_Values"));

                     Member_Type_Node := Insert_New_Simple_Type_Spec (Member_Node);

                     Parent_Node := Specific_Type_Spec (Member_Type_Node);
                     for I in 1 .. Dimensions loop
                        declare
                           Sequence_Node : Node_Id;
                        begin
                           Sequence_Node := New_Node (N_Sequence_Type);
                           Set_Template_Type_Spec (Parent_Node, Sequence_Node);
                           Set_Parent (Sequence_Node, Parent_Node);

                           Parent_Node := New_Node (N_Simple_Type_Spec);
                           Set_Specific_Type_Spec (Sequence_Node, Parent_Node);
                           Set_Parent (Parent_Node, Sequence_Node);
                        end;
                     end loop;

                     --  Parent_Node is <simple_type_spec> in innermost sequence.

                     State.Current_Node := Parent_Node;
                     Translate_Subtype_Mark (Component_Subtype_Mark, State);
                     State.Current_Node := Old_Current_Node;

                  end;
               end if;

               Control := Abandon_Children;
               --  Children were processed explicitly.
            end;

         when A_Record_Type_Definition =>              -- 3.8(2)
            if Trait_Kind (Element) = A_Limited_Trait then
               Type_Spec_Node := Insert_New_Opaque_Type (State.Current_Node);

               Control := Abandon_Children;
               --  Children not processed (the mapping is opaque).
            else
               declare
                  Struct_Type_Node : Node_Id;
                  Type_Identifier  : Name_Id;
                  --  The first <identifier> of the <type_declarator>

                  Discriminant_Part : constant Asis.Definition
                    := Declarations.Discriminant_Part
                    (Enclosing_Element (Element));
               begin
                  Type_Spec_Node := Insert_New_Constructed_Type (State.Current_Node);

                  Struct_Type_Node := New_Node (N_Struct_Type);
                  Set_Parent (Struct_Type_Node, Specific_Type_Spec (Type_Spec_Node));
                  Set_Structure (Specific_Type_Spec (Type_Spec_Node), Struct_Type_Node);

                  Type_Identifier := IDL_Syntax.Name
                    (Specific_Declarator (First (Declarators (State.Current_Node))));

                  Set_Name (Struct_Type_Node, New_Constructed_Type_Identifier
                            (Type_Identifier, "struct"));

                  Set_Previous_Current_Node (Element, State.Current_Node);
                  State.Current_Node := Struct_Type_Node;

                  if not Is_Nil (Discriminant_Part) then
                     Translate_Discriminant_Part (Discriminant_Part, State);
                  end if;
               end;
            end if;
            --  Process all children recursively.

         when
           A_Tagged_Record_Type_Definition       |     -- 3.8(2)
           A_Derived_Record_Extension_Definition =>    -- 3.4(2)
            Type_Spec_Node := Insert_New_Opaque_Type (State.Current_Node);

            Control := Abandon_Children;
            --  Children were processed explicitly

         when An_Access_Type_Definition =>             -- 3.10(2)
            --  This is the definition of a Remote Access to Class-Wide type.
            --  (RAS were processed in Process_Declaration directly; other
            --  access-to-object types are not allowed in the visible part
            --  of a DSA package).
            declare
               Designated_Subtype : constant Asis.Expression
                 := Asis.Definitions.Subtype_Mark
                 (Asis.Definitions.Access_To_Object_Definition (Element));
            begin
               Type_Spec_Node := Insert_New_Simple_Type_Spec (State.Current_Node);

               State.Current_Node := Specific_Type_Spec (Type_Spec_Node);
               pragma Assert (True
                 and then Expression_Kind (Designated_Subtype) = An_Attribute_Reference
                 and then Attribute_Kind (Designated_Subtype) = A_Class_Attribute);
               Translate_Subtype_Mark (Prefix (Designated_Subtype), State);
               State.Current_Node := Old_Current_Node;

               Set_Type_Spec (State.Current_Node, Type_Spec_Node);
               Set_Parent (Type_Spec_Node, State.Current_Node);

               Control := Abandon_Children;
               --  Child elements were processed explicitly.
            end;
      end case;
   end Process_Type_Definition;

   procedure Translate_Defining_Name
     (Name    : in Asis.Defining_Name;
      State   : in out Translator_State) is
      IDL_Name : Name_Id;
      Name_Image : constant Program_Text
        := Declarations.Defining_Name_Image (Name);
   begin
      if Is_Identical
        (Enclosing_Element (Name),
         Unit_Declaration (Enclosing_Compilation_Unit (Name)))
      then
         --  This is the defining name in a library_unit_declaration
         IDL_Name := New_Name (IDL_Module_Name
                               (Enclosing_Compilation_Unit (Name)));
      else
         case Defining_Name_Kind (Name) is
            when Not_A_Defining_Name =>
               Raise_Translation_Error
                 (Name, "Unexpected element (Not_A_Defining_Name).");
            when
              A_Defining_Identifier |
              A_Defining_Enumeration_Literal =>
               IDL_Name := New_Name (Name_Image);
            when A_Defining_Character_Literal =>
               IDL_Name := New_Name (Maps.Character_Literal_Identifier (Name_Image));
            when A_Defining_Operator_Symbol =>
               IDL_Name := New_Name (Maps.Operator_Symbol_Identifier (Name_Image));
            when A_Defining_Expanded_Name =>
               --  Cannot happen (this is a defining_program_unit_name,
               --  taken care of by "if" above.)
               raise ASIS_Failed;
         end case;
      end if;
      Set_Name (State.Current_Node, IDL_Name);
   end Translate_Defining_Name;

   procedure Translate_Subtype_Mark
     (Exp     : in Asis.Expression;
      State   : in out Translator_State) is
      Control : Traverse_Control := Continue;
      Current_Pass : constant Translation_Pass
        := State.Pass;
   begin
      State.Pass := Translate_Subtype_Mark;
      Translate_Tree (Exp, Control, State);
      State.Pass := Current_Pass;
   end Translate_Subtype_Mark;

   procedure Translate_Discriminant_Part
     (Def     : in Asis.Definition;
      State   : in out Translator_State) is
      Control : Traverse_Control := Continue;
      Current_Pass : constant Translation_Pass
        := State.Pass;
   begin
      State.Pass := Deferred_Discriminant_Part;
      Translate_Tree (Discriminant_Part (Enclosing_Element (Def)),
                      Control, State);
      State.Pass := Current_Pass;
   end Translate_Discriminant_Part;

   procedure Translate_Type_Definition
     (Def     : in Asis.Definition;
      State   : in out Translator_State) is
      Control : Traverse_Control := Continue;
      Current_Pass : constant Translation_Pass
        := State.Pass;
   begin
      State.Pass := CIAO.Translator.State.Type_Definition;
      Translate_Tree (Def, Control, State);
      State.Pass := Current_Pass;
   end Translate_Type_Definition;

   procedure Translate_Formal_Parameter
     (Specification    : in Asis.Definition;
      Is_Implicit_Self : in Boolean;
      State            : in out Translator_State) is
      Control : Traverse_Control := Continue;
      Current_Pass : constant Translation_Pass
        := State.Pass;
   begin
      if Is_Implicit_Self then
         State.Pass := CIAO.Translator.State.Self_Formal_Parameter;
      else
         State.Pass := CIAO.Translator.State.Normal_Formal_Parameter;
      end if;
      Translate_Tree (Specification, Control, State);
      State.Pass := Current_Pass;
   end Translate_Formal_Parameter;

   -----------------------------------------------------------
   -- Post_Translate_Element                                --
   -- Restore Current_Node after a node has been            --
   -- entirely constructed.                                 --
   -- Used as post-operation for Iterator.Traverse_Element. --
   -----------------------------------------------------------

   procedure Post_Translate_Element
     (Element : in Asis.Element;
      Control : in out Traverse_Control;
      State   : in out Translator_State) is
      Previous_Current_Node : constant Node_Id
        := Get_Previous_Current_Node (Element);
   begin
      if Previous_Current_Node /= Empty then
         State.Current_Node := Previous_Current_Node;
      end if;
   end Post_Translate_Element;

   ----------------------------------------------------
   -- Translate_Context_Clause                       --
   -- Translate the context clause of a library unit --
   -- into a set of preprocessor directives.         --
   ----------------------------------------------------

   procedure Translate_Context_Clause
     (Library_Unit : Asis.Compilation_Unit;
      State        : in out Translator_State) is
      Context_Clause_Items : constant Context_Clause_List
        := Context_Clause_Elements (Library_Unit);

      Defining_Names : constant Asis.Name_List
        := Names (Unit_Declaration (Library_Unit));
      Name  : constant Asis.Name := Defining_Names (Defining_Names'First);
      Include_Node : Node_Id;
   begin
      --  Include_Node := New_Include_Directive;
      --  Set_Parent (Include_Node, State.Current_Node);
      --  Add_Directive (State.Current_Node, Include_Node);
      --  Set_Name (Include_Node, New_Name ("ciao.idl"));
      --  Set_Unit_Used (Include_Node, True);

      for I in Context_Clause_Items'Range loop
         declare
            Clause : constant Context_Clause
              := Context_Clause_Items (I);
         begin
            case Clause_Kind (Clause) is
               when A_With_Clause =>
                  declare
                     Units : constant Name_List
                       := Asis.Clauses.Clause_Names (Clause);
                  begin
                     for J in Units'Range loop
                        declare
                           Unit_Declaration : constant Asis.Declaration
                             := Corresponding_Entity_Name_Declaration
                             (Units (J));
                           Unit_Translation : constant Node_Id
                             := Translate
                             (Enclosing_Compilation_Unit (Unit_Declaration));
                        begin
                           Include_Node := New_Include_Directive;
                           Set_Parent (Include_Node, State.Current_Node);
                           Add_Directive (State.Current_Node, Include_Node);
                           Set_Translated_Unit (Include_Node, Unit_Translation);

                           Set_Translation (Unit_Declaration, Include_Node);
                           --  The translation of the declaration of a withed
                           --  unit is a #include preprocessor directive node.

                           Set_Name (Include_Node, New_Name
                                     (To_Wide_String
                                      (IDL_File_Name
                                       (Ada_File_Name
                                        (Asis.Compilation_Units.Unit_Full_Name
                                         (Enclosing_Compilation_Unit
                                          (Unit_Declaration)))))));
                        end;
                     end loop;
                  end;

               when others =>
                  null;
            end case;
         end;
      end loop;

      --  If this is a child unit of a library unit, then its
      --  visible part has visibility on the visible part of
      --  its parent.
      if Defining_Name_Kind (Name) = A_Defining_Expanded_Name then
         declare
            Include_Node : Node_Id;
         begin
            Include_Node := New_Include_Directive;
            Set_Parent (Include_Node, State.Current_Node);
            Add_Directive (State.Current_Node, Include_Node);

            Set_Name (Include_Node, New_Name
                      (To_Wide_String
                       (IDL_File_Name
                        (Ada_File_Name
                         (Asis.Compilation_Units.Unit_Full_Name
                          (Enclosing_Compilation_Unit
                           (Corresponding_Entity_Name_Declaration
                            (Defining_Prefix (Name)))))))));
         end;
      end if;

   end Translate_Context_Clause;

   function Translate (LU : in Compilation_Unit) return Node_Id is
      Category : constant Unit_Categories
        := Unit_Category (LU);
   begin
      if Category = Other then
         Raise_Translation_Error
           (Nil_Element,
            "The unit is not a Pure, Remote Types or Remote Call Interface package specification.");
      end if;

      declare
         D : constant Declaration
           := Unit_Declaration (LU);

         C : Traverse_Control := Continue;
         S : Translator_State;
      begin
         Initialize_Translator_State
           (Category => Category,
            State    => S);
         Translate_Context_Clause (LU, S);
         Translate_Tree (D, C, S);
         return S.IDL_Tree;
      end;
   end Translate;

end CIAO.Translator;
