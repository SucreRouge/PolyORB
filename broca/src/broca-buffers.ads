with Ada.Unchecked_Deallocation;

package Broca.Buffers is

   pragma Elaborate_Body;

   --  True if this machine use little endian byte order.
   Is_Little_Endian : Boolean;

   --  Buffer to/from network before unmarshalling or after marshalling.
   --  Must start at 0, according to CORBA V2.2 13.3

   type Byte is mod 2 ** 8;
   type Buffer_Index_Type is mod 2 ** 32;
   type Buffer_Type is array (Buffer_Index_Type range <>) of Byte;
   type Buffer_Access is access Buffer_Type;

   --  A buffer with the current position, as needed by unmarshall and
   --  endianness.
   type Buffer_Descriptor is
      record
         Pos           : Buffer_Index_Type := 0;
         Little_Endian : Boolean := False;
         Buffer        : Buffer_Access := null;
      end record;

   subtype Alignment_Type is Buffer_Index_Type range 1 .. 8;

   procedure Align_Size
     (Buffer    : in out Buffer_Descriptor;
      Alignment : in Alignment_Type);
   pragma Inline (Align_Size);
   --  Align Buffer size to Alignment

   procedure Allocate_Buffer (Buffer : in out Buffer_Descriptor);
   --  Allocate the buffer using pos and clear pos. Use local endianess.

   procedure Allocate_Buffer_And_Set_Pos
     (Buffer : in out Buffer_Descriptor;
      Size   : in Buffer_Index_Type);
   --  Be sure Buffer.Buffer is at least of length Size.  Set
   --  Buffer.Pos to Size. Endianess is already set.

   procedure Allocate_Buffer_And_Clear_Pos
     (Buffer : in out Buffer_Descriptor;
      Size   : in Buffer_Index_Type);
   --  Be sure Buffer.Buffer is at least of length Size.  Set
   --  Buffer.Pos to 0. Endianess is already set.

   procedure Append_Buffer
     (Target : in out Buffer_Descriptor;
      Source : in Buffer_Descriptor);
   --  Append Source into Target

   procedure Compute_New_Size
     (Target : in out Buffer_Descriptor;
      Source : in Buffer_Descriptor);
   --  Compute new size of Target when Source appended

   procedure Compute_New_Size
     (Buffer : in out Buffer_Descriptor;
      Align  : in Alignment_Type;
      Size   : in Buffer_Index_Type);

   procedure Dump (Buffer : in Buffer_Type);
   --  Display Buffer

   procedure Extract_Buffer
     (Target : in out Buffer_Descriptor;
      Source : in out Buffer_Descriptor;
      Length : in Buffer_Index_Type);
   --  Extract Length bytes from Source, update position of Source and
   --  copy it to Target. Pos is reset before copying and not updated,
   --  and Little_Endian flag is copied from Source.

   procedure Free is
      new Ada.Unchecked_Deallocation (Buffer_Type, Buffer_Access);

   procedure Read
     (Buffer  : in out Buffer_Descriptor;
      Bytes   : out Buffer_Type);
   pragma Inline (Read);
   --  Read from Buffer an array of bytes

   function Size_Left (Buffer : Buffer_Descriptor) return  Buffer_Index_Type;
   function Size      (Buffer : Buffer_Descriptor) return Buffer_Index_Type;

   procedure Write
     (Buffer  : in out Buffer_Descriptor;
      Bytes   : in Buffer_Type);
   pragma Inline (Write);
   --  Write into Buffer an array of bytes

end Broca.Buffers;
